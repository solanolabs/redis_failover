require 'spec_helper'

module RedisFailover
  class LightNodeManager
    def initialize
      @node_states = {}
    end

    def notify_state_change(node, state)
      @node_states[node] = state
    end

    def state_for(node)
      @node_states[node]
    end
  end

  describe NodeWatcher do
    let(:node_manager) { LightNodeManager.new }
    let(:node) { Node.new(:host => 'host', :port => 123).extend(RedisStubSupport) }

    describe '#watch' do
      it 'properly informs manager of unavailable node' do
        watcher = NodeWatcher.new(node_manager, node, 1)
        watcher.watch
        sleep(3)
        node.redis.make_unavailable!
        sleep(3)
        watcher.shutdown
        node_manager.state_for(node).should == :unavailable
      end

      it 'properly informs manager of available node' do
        node_manager.notify_state_change(node, :unavailable)
        watcher = NodeWatcher.new(node_manager, node, 1)
        watcher.watch
        sleep(3)
        watcher.shutdown
        node_manager.state_for(node).should == :available
      end
    end
  end
end