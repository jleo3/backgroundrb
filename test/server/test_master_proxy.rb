require File.join(File.dirname(__FILE__) + "/..","bdrb_test_helper")
require "mocha"

context "Master proxy for reloadable workers" do
  ENV["RAILS_ENV"] = "production"

  before(:each) do
    BDRB_CONFIG.set({:schedules=>
                      { :foo_worker => { :barbar => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }},
                        :bar_worker => { :do_job => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }} },
                     :backgroundrb =>  { :log => "foreground", 
                                         :debug_log => false, 
                                         :environment => "production", 
                                         :port => 11006, 
                                         :ip => "localhost"}
                    })

    Packet::Reactor.stubs(:run)
    @master_proxy = BackgrounDRb::MasterProxy.new
  end

  specify "should load schedule of workers which are reloadable" do
    @master_proxy.reloadable_workers.should_not == []
    @master_proxy.reloadable_workers.should include(BarWorker)
    @master_proxy.reloadable_workers.should include(FooWorker)
    @master_proxy.worker_triggers.should_not == {}
    @master_proxy.worker_triggers.keys.should include(:bar_worker)
    @master_proxy.worker_triggers[:bar_worker].keys.should include(:do_job)

    @master_proxy.worker_triggers[:bar_worker][:do_job].should_not == { }
  end

  specify "load schedule should load schedule of worker specified" do
    sheep = mock()
    sheep.expects(:send_request).at_most(4)
    live_workers = Hash.new(sheep)
    crap_reactor = mock()
    crap_reactor.expects(:start_worker).at_most(2)
    crap_reactor.expects(:live_workers).at_most(4).returns(live_workers)
    @master_proxy.reactor = crap_reactor
    @master_proxy.reload_workers
  end

  specify "should not run worker methods which are not ready to run" do
    sheep = mock()
    sheep.expects(:send_request).at_most(4)
    live_workers = Hash.new(sheep)
    crap_reactor = mock()
    crap_reactor.expects(:start_worker).at_most(2)
    crap_reactor.expects(:live_workers).at_most(4).returns(live_workers)
    @master_proxy.reactor = crap_reactor
    @master_proxy.reload_workers
  end
end
