require 'spec_helper'

describe Delayed::Backend::Redis::Job do
  it_should_behave_like 'a delayed_job backend'

  describe '.push' do
    subject { described_class.create(:queue => 'test', :payload_object => SimpleJob.new) }
  
    it 'should add the job to the named queue' do
      payload = subject.payload_object
      described_class.instance_eval{ pop('test') }.payload_object.should == payload
    end
  
    specify { subject; described_class.queues.should include('test') }
  end
  
  describe '.enqueue' do
    context 'without a specific queue' do
      subject { described_class.enqueue SimpleJob.new }
    
      it 'should be added to default queue' do
        payload = subject.payload_object
        job = described_class.instance_eval{ pop('default') }
        job.payload_object.should == payload
      end      
    end
  end
end