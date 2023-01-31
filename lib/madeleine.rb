# frozen_string_literal: true

# typed: strict

require "sqlite3"

module Madeleine
  # An append-only implementation of parts of Set from the stdlib that uses
  # constant memory regardless of the set size by spilling data to disk (using
  # SQLite) once the set size crosses some threshold.
  class AppendSet
    # Interface to abstract over Set / SQLite
    module Store
      extend T::Sig
      extend T::Helpers
      extend T::Generic

      interface!

      Item = type_member { { upper: Object } }

      sig { abstract.returns(Integer) }
      def size; end

      sig { abstract.params(item: Item).returns(T::Boolean) }
      def include?(item); end

      sig { abstract.params(items: T::Enumerable[Item]).void }
      def add(items); end
    end

    # Implementation for Set
    class SetStore
      extend T::Sig
      extend T::Generic

      Item = type_member { { upper: Object } }

      include Store

      sig { void }
      def initialize
        @set = T.let(Set.new, T::Set[Item])
      end

      sig { returns(T::Enumerable[Item]) }
      def all
        @set
      end

      sig { override.returns(Integer) }
      def size
        @set.size
      end

      sig { override.params(item: Item).returns(T::Boolean) }
      def include?(item)
        @set.include?(item)
      end

      sig { override.params(items: T::Enumerable[Item]).void }
      def add(items)
        items.each { |item| @set.add(item) }
      end
    end

    # Implementation for SQLite
    class SQLiteStore
      extend T::Sig
      extend T::Generic

      Item = type_member { { upper: Object } }

      include Store

      sig { void }
      def initialize
        # Both +@tempfile+ and +@sqlite+ get automatically cleaned up (closed,
        # deleted from disk) when this object goes out of scope. Worst-case, files
        # on disk should get reaped at process exit or dyno reboot.
        @tempfile = T.let(Tempfile.new(%w[AppendSetSQLiteStore .sqlite3]), Tempfile)

        # We immediately unlink the file so that it is guaranteed to be removed
        # from disk on process exit (by the OS). In testing, I've found that Ruby
        # guarantee of unlinking the file in the finalizer doesn't always seem to
        # succeed; not sure why. +unlink+ is safe here because the @sqlite
        # instance variable holds an open file handle - as long as a file has an
        # open handle on a unix-like OS, it won't actually be deleted until that
        # file handle is closed (though it does become invisible to commands like
        # `ls`).
        @sqlite = T.let(SQLite3::Database.new(@tempfile), SQLite3::Database)
        @tempfile.unlink

        # This is a non-persistent db so make it go fast
        # Partially based on https://github.com/avinassh/fast-sqlite3-inserts
        @sqlite.execute "pragma synchronous=off"
        @sqlite.execute "pragma journal_mode=off"
        @sqlite.execute "pragma locking_mode=exclusive"
        @sqlite.execute "pragma temp_store=memory"

        # The single table that will store data
        @sqlite.execute "create table items (item text primary key)"

        # Prepare our three statements
        @count_statement = T.let(@sqlite.prepare("select count(item) from items"), SQLite3::Statement)
        @add_statement =
          T.let(@sqlite.prepare("insert into items values (?) on conflict (item) do nothing"), SQLite3::Statement)
        @include_statement =
          T.let(@sqlite.prepare("select exists(select 1 from items where item = ?)"), SQLite3::Statement)
      end

      sig { override.returns(Integer) }
      def size
        result = @count_statement.execute
        result.first.first
      end

      sig { override.params(item: Item).returns(T::Boolean) }
      def include?(item)
        result = @include_statement.execute(marshal(item))
        result.first.first == 1
      end

      sig { override.params(items: T::Enumerable[Item]).void }
      def add(items)
        # transaction should improve bulk insert performance
        @sqlite.execute "begin"
        items.each { |item| @add_statement.execute(marshal(item)) }
        @sqlite.execute "commit"
      end

      private

      sig { params(item: Item).returns(String) }
      def marshal(item)
        Base64.encode64(Marshal.dump(item))
      end
    end

    # Facade that implements Store by proxying to SetStore or SQLiteStore. The
    # spillover logic is also included here, as well as an optimization for any?
    extend T::Sig
    extend T::Generic
    include Store
    Item = type_member { { upper: Object } }

    # This is pretty arbitrary, but it seems to correlate well with efficient
    # sqlite transaction performance and it gives us enough granularity in
    # checkpointing to see if we should spill
    ADD_BATCH_SIZE = 50_000

    # This is pretty arbitrary, but assuming that each key is ~200 bytes in memory
    # (a conservative estimate), it means that we'll never burn more than 100MB of
    # RAM on this set before we go to disk, which should be managable on our
    # infra. Ideally we could express this as a byte threshold, not an item
    # threshold - I couldn't find an easy / cheap way to do that in Ruby.
    SPILL_THRESHOLD = 500_000

    sig { void }
    def initialize
      @store = T.let(SetStore[Item].new, Store[Item])
      @spilled = T.let(false, T::Boolean)
    end

    sig { returns(T::Boolean) }
    def any?
      if @spilled
        # We must be non-empty if we've spilled to SQLite, so avoid an expensive
        # call to the DB to check
        true
      else
        set_store = T.cast(@store, SetStore[Item])
        set_store.all.any?
      end
    end

    sig { override.returns(Integer) }
    def size
      @store.size
    end

    sig { override.params(item: Item).returns(T::Boolean) }
    def include?(item)
      @store.include?(item)
    end

    sig { override.params(items: T::Enumerable[Item]).void }
    def add(items)
      items.each_slice(ADD_BATCH_SIZE) do |slice|
        @store.add(slice)
        spill_if_needed!
      end
    end

    private

    sig { void }
    def spill_if_needed!
      return if @spilled
      return if @store.size < SPILL_THRESHOLD

      set_store = T.cast(@store, SetStore[Item])
      sqlite_store = SQLiteStore.new
      sqlite_store.add(set_store.all)
      @store = sqlite_store
      @spilled = true
    end
  end
end
