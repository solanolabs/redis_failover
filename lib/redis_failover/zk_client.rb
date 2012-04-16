module RedisFailover
  # ZkClient is a thin wrapper over the ZK client to gracefully handle reconnects
  # when a session expires.
  class ZkClient
    include Util

    MAX_RECONNECTS = 3

    def initialize(servers)
      @servers = servers
      @lock = Mutex.new
      build_client
    end

    def get(*args, &block)
      perform_with_reconnect { @client.get(*args, &block) }
    end

    def set(*args, &block)
      perform_with_reconnect { @client.set(*args, &block) }
    end

    def watcher(*args, &block)
      perform_with_reconnect { @client.watcher(*args, &block) }
    end

    def stat(*args, &block)
      perform_with_reconnect { @client.stat(*args, &block) }
    end

    def create(*args, &block)
      perform_with_reconnect { @client.create(*args, &block) }
    end

    private

    def perform_with_reconnect
      tries = 0
      begin
        yield
      rescue ZookeeperExceptions::ZookeeperException::SessionExpired
        logger.info("Zookeeper client session expired, rebuilding client.")
        if tries < MAX_RECONNECTS
          tries += 1
          build_client
          sleep(2) && retry
        end

        raise
      end
    end

    def build_client
      @lock.synchronize do
        begin
          close_client
          @client = ZK.new(@servers)
          unless @client.connected?
            raise ZookeeperError, "Not in connected state, client: #{@client}"
          end
          @client.on_expired_session { build_client }
          logger.info("Communicating with zookeeper servers #{@servers}")
        rescue ZookeeperExceptions::ZookeeperException => ex
          raise ZookeeperError, "Failed to connect, error: #{ex.message}"
        end
      end
    end

    def close_client
      if @client
        @client.close!
      end
    rescue ZookeeperExceptions::ZookeeperException
      # best effort
    end
  end
end