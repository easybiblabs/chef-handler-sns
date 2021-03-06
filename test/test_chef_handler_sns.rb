require 'helper'
require 'chef/node'
require 'chef/run_status'

class AWS::FakeSNS
  attr_reader :sns_new

  def initialize(config)
    @sns_new = true
    return self
  end

  def topics
    {
      'arn:aws:sns:***' => AWS::SNS::Topic.new('arn:aws:sns:***')
    }
  end

end

class Chef::Handler::FakeSns < Chef::Handler::Sns

  def get_sns_subject
    sns_subject
  end

  def get_sns_body
    sns_body
  end

end

describe Chef::Handler::Sns do
  before do
    AWS::SNS::Topic.any_instance.stubs(:publish).returns(true)
    # avoid File.read("endpoints.json")
    AWS::Core::Endpoints.stubs(:endpoints).returns({
      'regions' => {
        'us-east-1' => {
          'sns' => {
            'http' => true,
            'https' => true,
            'hostname' => 'sns.us-east-1.amazonaws.com',
          }
        }
      }
    })

    @node = Chef::Node.new
    @node.name('test')
    Chef::Handler::Sns.any_instance.stubs(:node).returns(@node)
    Chef::Handler::FakeSns.any_instance.stubs(:node).returns(@node)

    @run_status = if Gem.loaded_specs['chef'].version > Gem::Version.new('0.12.0')
      Chef::RunStatus.new(@node, {})
    else
      Chef::RunStatus.new(@node)
    end

    @run_status.start_clock
    @run_status.stop_clock

    @config = {
      :access_key => '***AMAZON-KEY***',
      :secret_key => '***AMAZON-SECRET***',
      :topic_arn => 'arn:aws:sns:***',
    }
  end

  it 'should read the configuration options on initialization' do
    @sns_handler = Chef::Handler::Sns.new(@config)
    assert_equal @sns_handler.access_key, @config[:access_key]
    assert_equal @sns_handler.secret_key, @config[:secret_key]
  end

  it 'should be able to change configuration options using method calls' do
    @sns_handler = Chef::Handler::Sns.new
    @sns_handler.access_key(@config[:access_key])
    @sns_handler.secret_key(@config[:secret_key])
    assert_equal @sns_handler.access_key, @config[:access_key]
    assert_equal @sns_handler.secret_key, @config[:secret_key]
  end

  it 'should try to send a SNS message when properly configured' do
    @sns_handler = Chef::Handler::Sns.new(@config)
    AWS::SNS::Topic.any_instance.expects(:publish).once

    @sns_handler.run_report_safely(@run_status)
  end

  it 'should create a AWS::SNS object' do
    @sns_handler = Chef::Handler::Sns.new(@config)
    fake_sns = AWS::FakeSNS.new({
      :access_key_id => @config[:access_key],
      :secret_access_key => @config[:secret_key],
      :logger => Chef::Log
    })
    AWS::SNS.stubs(:new).returns(fake_sns)
    @sns_handler.run_report_safely(@run_status)

    assert_equal fake_sns.sns_new, true
  end

  it 'should detect the AWS region automatically' do
    @node.set['ec2']['placement_availability_zone'] = 'eu-west-1a'
    @sns_handler = Chef::Handler::Sns.new(@config)
    @sns_handler.run_report_safely(@run_status)

    @sns_handler.get_region.must_equal 'eu-west-1'
  end

  it 'should not detect AWS region automatically whan manually set' do
    @node.set['ec2']['placement_availability_zone'] = 'eu-west-1a'
    @config[:region] = 'us-east-1'
    @sns_handler = Chef::Handler::Sns.new(@config)
    @sns_handler.run_report_safely(@run_status)

    @sns_handler.get_region.must_equal 'us-east-1'
  end

  it 'should be able to generate the default subject in chef-client' do
    Chef::Config[:solo] = false
    @fake_sns_handler = Chef::Handler::FakeSns.new(@config)
    Chef::Handler::FakeSns.any_instance.stubs(:node).returns(@node)
    @fake_sns_handler.run_report_unsafe(@run_status)

    assert_equal @fake_sns_handler.get_sns_subject, 'Chef Client success in test'
  end

  it 'should be able to generate the default subject in chef-solo' do
    Chef::Config[:solo] = true
    @fake_sns_handler = Chef::Handler::FakeSns.new(@config)
    Chef::Handler::FakeSns.any_instance.stubs(:node).returns(@node)
    @fake_sns_handler.run_report_unsafe(@run_status)

    assert_equal @fake_sns_handler.get_sns_subject, 'Chef Solo success in test'
  end

  it 'should use the configured subject when set' do
    @config[:subject] = 'My Subject'
    @fake_sns_handler = Chef::Handler::FakeSns.new(@config)
    Chef::Handler::FakeSns.any_instance.stubs(:node).returns(@node)
    @fake_sns_handler.run_report_unsafe(@run_status)

    assert_equal @fake_sns_handler.get_sns_subject, 'My Subject'
  end

  it 'should be able to generate the default message body' do
    @fake_sns_handler = Chef::Handler::FakeSns.new(@config)
    Chef::Handler::FakeSns.any_instance.stubs(:node).returns(@node)
    @fake_sns_handler.run_report_unsafe(@run_status)

    @fake_sns_handler.get_sns_body.must_match Regexp.new('Node Name: test')
  end

  it 'should throw an exception when the body template file does not exist' do
    @config[:body_template] = '/tmp/nonexistent-template.erb'
    @sns_handler = Chef::Handler::Sns.new(@config)

    assert_raises(Chef::Exceptions::ValidationFailed) { @sns_handler.run_report_unsafe(@run_status) }
  end

  it 'should be able to generate the body template when configured as an option' do
    body_msg = 'My Template'
    @config[:body_template] = '/tmp/existing-template.erb'
    ::File.stubs(:exists?).with(@config[:body_template]).returns(true)
    IO.stubs(:read).with(@config[:body_template]).returns(body_msg)

    fake_sns = AWS::FakeSNS.new({})
    AWS::SNS.stubs(:new).returns(fake_sns)
    @fake_sns_handler = Chef::Handler::FakeSns.new(@config)
    Chef::Handler::FakeSns.any_instance.stubs(:node).returns(@node)
    @fake_sns_handler.run_report_unsafe(@run_status)

    assert_equal @fake_sns_handler.get_sns_body, body_msg
  end

  it 'should publish messages if node["opsworks"]["activity"] does not exist' do
    @sns_handler = Chef::Handler::Sns.new(@config)
    AWS::SNS::Topic.any_instance.expects(:publish).once

    @sns_handler.run_report_safely(@run_status)
  end

  it 'should publish messages if node["opsworks"]["activity"] matches allowed acvities' do
    @node.set['opsworks']['activity'] = 'deploy'
    @config[:filter_opsworks_activity] = ['deploy', 'setup']

    @sns_handler = Chef::Handler::Sns.new(@config)
    AWS::SNS::Topic.any_instance.expects(:publish).once
    @sns_handler.run_report_safely(@run_status)
  end

  it 'should not publish messages if node["opsworks"]["activity"] differs from allowed acvities' do
    @node.set['opsworks']['activity'] = 'configure'
    @config[:filter_opsworks_activity] = ['deploy', 'setup']

    @sns_handler = Chef::Handler::Sns.new(@config)
    AWS::SNS::Topic.any_instance.expects(:publish).never
    @sns_handler.run_report_safely(@run_status)
  end

  it 'should not publish messages if node["opsworks"]["activity"] is set, but the node attribute is missing' do
    @config[:filter_opsworks_activity] = ['deploy', 'setup']

    @sns_handler = Chef::Handler::Sns.new(@config)
    AWS::SNS::Topic.any_instance.expects(:publish).never
    @sns_handler.run_report_safely(@run_status)
  end

end
