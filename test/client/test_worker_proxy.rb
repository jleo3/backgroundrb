require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require File.join(File.dirname(__FILE__) + "/../bdrb_client_test_helper")

describe "For Worker Proxy in general" do
  before(:each) do
    BDRB_CONFIG.set({:schedules=> {
                        :foo_worker => { :barbar=>{:trigger_args=>"*/5 * * * * * *"}}},
                      :backgroundrb =>{:port=>11008, :ip=>"0.0.0.0", :environment=> "production"}
                    })

    @cluster_conn = mock
    @worker_proxy = BackgrounDRb::RailsWorkerProxy.new(:hello_worker,nil,@cluster_conn)
  end

  it "should let you fetch results" do
    @cluster_conn.expects(:backend_connections).returns([])
    foo = @worker_proxy.ask_result(:foobar)
    foo.should == nil
  end

  it "should let you invoke sync task  methods" do
    actual_conn = mock()
    actual_conn.expects(:server_info).returns("localhost:11008")
    actual_conn.expects(:send_request).returns({ :data => 20, :result_flag => "ok",:result => true, :type => :response})
    @cluster_conn.expects(:choose_server).returns(actual_conn)
    a = @worker_proxy.hello_world(:args => "sucks")
    a.should == 20
  end

  it "should let you invoke delete method" do
    actual_conn = mock()
    actual_conn.expects(:delete_worker).with(:worker => :hello_worker).returns(nil)
    @cluster_conn.expects(:backend_connections).returns(Array(actual_conn))
    @worker_proxy.delete
  end

  it "delete method should run on all nodes" do
    conn_array = (0..3).map do |i|
      t = mock()
      t.expects(:delete_worker).with(:worker => :hello_worker).returns(nil)
      t
    end
    @cluster_conn.expects(:backend_connections).returns(conn_array)
    @worker_proxy.delete
  end

  it "should let you invoke worker_info method" do
    backend_connections = []
    2.times { |i|
      actual_conn = mock()
      actual_conn.expects(:worker_info).with(:worker => :hello_worker).returns(i)
      backend_connections << actual_conn
    }
    @cluster_conn.expects(:backend_connections).returns(backend_connections)
    a = @worker_proxy.worker_info
    a.should == [0,1]
  end

  it "should let you run async tasks" do
    actual_conn = mock()
    actual_conn.expects(:ask_work).with(:arg => :hello,:worker => :hello_worker,:worker_method => 'foobar',:job_key => 'boy').returns(nil)
    @cluster_conn.expects(:find_connection).returns(actual_conn)
    @worker_proxy.async_foobar(:arg => :hello,:job_key => "boy",
                               :host => "192.168.2.100:100")
  end

  it "for enqueued tasks" do
    BdrbJobQueue.expects(:insert_job).with() { |value|
      value[:worker_name].should == "hello_worker"
      value[:worker_method].should == "foobar"
      value[:scheduled_at].should_not == nil
      value[:job_key] == "catz"
    }
    @worker_proxy.enq_foobar(:arg => :hello,:job_key => "catz")
  end


  it "should run enqueued tasks in order if they have priorites" do


    [2,4,10].each do |priority|
      BdrbJobQueue.expects(:insert_job).with() { |value|
        value[:worker_name].should == "hello_worker"
        value[:worker_method].should == "foobar"
        value[:scheduled_at].should_not == nil
        value[:job_key] == priority.to_s
        value[:priority] == priority
      }.once
    end
    
    @worker_proxy.enq_foobar(:job_key => '4', :priority => 4, :arg => :hello)
    @worker_proxy.enq_foobar(:job_key => '2', :priority => 2, :arg => :hello)
    @worker_proxy.enq_foobar(:job_key => '10', :priority => 10, :arg => :hello)
  end

  it "for removing tasks from the queue" do
    BdrbJobQueue.expects(:remove_job).with() do |value|
      value[:worker_name] == "hello_worker"
      value[:worker_method] == "foobar"
      value[:job_key] == "catz"
    end
    @worker_proxy.deq_foobar(:job_key => "catz")
  end

  it "should run task on all servers if asked" do
    backend_connections = []
    2.times { |i|
      actual_conn = mock()
      actual_conn.expects(:ask_work).with(:worker => :hello_worker,:worker_method => 'foobar',:job_key => 'hello')
      backend_connections << actual_conn
    }
    @cluster_conn.expects(:backend_connections).returns(backend_connections)
    a = @worker_proxy.async_foobar(:job_key => "hello",:host => :all)
  end

  it "Should allow method with empty params to work" do
    actual_conn = mock()
    actual_conn.expects(:server_info).returns("localhost:11211")
    actual_conn.expects(:ask_work).with(:worker => :hello_worker,:worker_method => 'foobar').returns(nil)
    @cluster_conn.expects(:choose_server).returns(actual_conn)
    @worker_proxy.async_foobar
  end

end
