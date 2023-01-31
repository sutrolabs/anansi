# frozen_string_literal: true

# typed: strict

require_relative "madeleine/version"
require "sqlite3"

module Madeleine
  # An append-only implementation of parts of Set from the stdlib that uses
  # constant memory regardless of the set size by spilling data to disk (using
  # SQLite) once the set size crosses some threshold.
  class AppendSet
    # Interface to abstract over Set / SQLite
    module Store
      def size; end

      def include?(item); end

      def add(items); end
    end

    # Implementation for Set
    class SetStore
      include Store

      def initialize
        @set = Set.new
      end

      def all
        @set
      end

      def size
        @set.size
      end

      def include?(item)
        @set.include?(item)
      end

      def add(items)
        items.each { |item| @set.add(item) }
      end
    end

    # Implementation for SQLite
    class SQLiteStore
      include Store

      def initialize
        # Both +@tempfile+ and +@sqlite+ get automatically cleaned up (closed,
        # deleted from disk) when this object goes out of scope. Worst-case, files
        # on disk should get reaped at process exit or dyno reboot.
        @tempfile = Tempfile.new(%w[AppendSetSQLiteStore .sqlite3])

        # We immediately unlink the file so that it is guaranteed to be removed
        # from disk on process exit (by the OS). In testing, I've found that Ruby
        # guarantee of unlinking the file in the finalizer doesn't always seem to
        # succeed; not sure why. +unlink+ is safe here because the @sqlite
        # instance variable holds an open file handle - as long as a file has an
        # open handle on a unix-like OS, it won't actually be deleted until that
        # file handle is closed (though it does become invisible to commands like
        # `ls`).
        @sqlite = SQLite3::Database.new(@tempfile)
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
        @count_statement = @sqlite.prepare("select count(item) from items")
        @add_statement = @sqlite.prepare("insert into items values (?) on conflict (item) do nothing")
        @include_statement = @sqlite.prepare("select exists(select 1 from items where item = ?)")
      end

      def size
        result = @count_statement.execute
        result.first.first
      end

      def include?(item)
        result = @include_statement.execute(marshal(item))
        result.first.first == 1
      end

      def add(items)
        # Transaction should improve bulk insert performance
        @sqlite.execute "begin"
        items.each { |item| @add_statement.execute(marshal(item)) }
        @sqlite.execute "commit"
      end

      private

      def marshal(item)
        Base64.encode64(Marshal.dump(item))
      end
    end

    # Facade that implements Store by proxying to SetStore or SQLiteStore. The
    # spillover logic is also included here, as well as an optimization for +any?+

    # This is pretty arbitrary, but it seems to correlate well with efficient
    # sqlite transaction performance and it gives us enough granularity in
    # checkpointing to see if we should spill
    ADD_BATCH_SIZE = 50_000

    # This is pretty arbitrary, but assuming that each key is ~200 bytes in memory
    # (a conservative estimate), it means that we'll never burn more than 100MB of
    # RAM on this set before we go to disk. Ideally we could express this as a byte
    # threshold, not an item threshold - I couldn't find an easy / cheap way to do
    # that in Ruby.
    SPILL_THRESHOLD = 500_000

    def initialize
      @store = SetStore.new
      @spilled = false
    end

    def any?
      if @spilled
        # We must be non-empty if we've spilled to SQLite, so avoid an expensive
        # call to the DB to check
        true
      else
        @store.all.any?
      end
    end

    def size
      @store.size
    end

    def include?(item)
      @store.include?(item)
    end

    def add(items)
      items.each_slice(ADD_BATCH_SIZE) do |slice|
        @store.add(slice)
        spill_if_needed!
      end
    end

    private

    def spill_if_needed!
      return if @spilled
      return if @store.size < SPILL_THRESHOLD

      set_store = @store
      sqlite_store = SQLiteStore.new
      sqlite_store.add(set_store.all)
      @store = sqlite_store
      @spilled = true
    end
  end
end
