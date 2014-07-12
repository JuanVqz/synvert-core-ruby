require 'spec_helper'

describe Parser::AST::Node do
  describe '#name' do
    it 'gets for class node' do
      node = parse('class Synvert; end')
      expect(node.name).to eq parse('Synvert')

      node = parse('class Synvert::Rewriter::Instance; end')
      expect(node.name).to eq parse('Synvert::Rewriter::Instance')
    end

    it 'gets for module node' do
      node = parse('module Synvert; end')
      expect(node.name).to eq parse('Synvert')
    end

    it 'gets for def node' do
      node = parse('def current_node; end')
      expect(node.name).to eq :current_node
    end

    it 'gets for defs node' do
      node = parse('def self.current_node; end')
      expect(node.name).to eq :current_node
    end
  end

  describe '#receiver' do
    it 'gets for send node' do
      node = parse('FactoryGirl.create :post')
      expect(node.receiver).to eq parse('FactoryGirl')
    end
  end

  describe '#message' do
    it 'gets for send node' do
      node = parse('FactoryGirl.create :post')
      expect(node.message).to eq :create
    end
  end

  describe '#arguments' do
    it 'gets for send node' do
      node = parse("FactoryGirl.create :post, title: 'post'")
      expect(node.arguments).to eq parse("[:post, title: 'post']").children
    end

    it 'gets for block node' do
      source = 'RSpec.configure do |config|; end'
      node = parse(source)
      instance = double(current_source: source)
      Synvert::Rewriter::Instance.current = instance
      expect(node.arguments.map { |argument| argument.to_source }).to eq ['config']
    end

    it 'gets for defined? node' do
      node = parse('defined?(Bundler)')
      expect(node.arguments).to eq [parse('Bundler')]
    end
  end

  describe '#caller' do
    it 'gets for block node' do
      node = parse('RSpec.configure do |config|; end')
      expect(node.caller).to eq parse('RSpec.configure')
    end
  end

  describe '#body' do
    it 'gets one line for block node' do
      node = parse('RSpec.configure do |config|; include EmailSpec::Helpers; end')
      expect(node.body).to eq [parse('include EmailSpec::Helpers')]
    end

    it 'gets multiple lines for block node' do
      node = parse('RSpec.configure do |config|; include EmailSpec::Helpers; include EmailSpec::Matchers; end')
      expect(node.body).to eq [parse('include EmailSpec::Helpers'), parse('include EmailSpec::Matchers')]
    end

    it 'gets for begin node' do
      node = parse('foo; bar')
      expect(node.body).to eq [parse('foo'), parse('bar')]
    end

    it 'gets for def node' do
      node = parse('def test; foo; bar; end')
      expect(node.body).to eq [parse('foo'), parse('bar')]
    end
  end

  describe "#keys" do
    it 'gets for hash node' do
      node = parse("{:foo => :bar, 'foo' => 'bar'}")
      expect(node.keys).to eq [parse(':foo'), parse("'foo'")]
    end
  end

  describe "#values" do
    it 'gets for hash node' do
      node = parse("{:foo => :bar, 'foo' => 'bar'}")
      expect(node.values).to eq [parse(':bar'), parse("'bar'")]
    end
  end

  describe "#has_key?" do
    it "gets true if key exists" do
      node = parse("{:foo => :bar}")
      expect(node.has_key?(:foo)).to be_truthy
    end

    it "gets false if key does not exist" do
      node = parse("{:foo => :bar}")
      expect(node.has_key?('foo')).to be_falsey
    end
  end

  describe "#hash_value" do
    it "gets value of specified key" do
      node = parse("{:foo => :bar}")
      expect(node.hash_value(:foo)).to eq parse(':bar')
    end

    it "gets nil if key does not exist" do
      node = parse("{:foo => :bar}")
      expect(node.hash_value(:bar)).to be_nil
    end
  end

  describe "#key" do
    it 'gets for pair node' do
      node = parse("{:foo => 'bar'}").children[0]
      expect(node.key).to eq parse(':foo')
    end
  end

  describe "#value" do
    it 'gets for hash node' do
      node = parse("{:foo => 'bar'}").children[0]
      expect(node.value).to eq parse("'bar'")
    end
  end

  describe "#condition" do
    it 'gets for if node' do
      node = parse('if defined?(Bundler); end')
      expect(node.condition).to eq parse('defined?(Bundler)')
    end
  end

  describe "#to_value" do
    it 'gets for string' do
      node = parse("'str'")
      expect(node.to_value).to eq "str"
    end

    it 'gets for symbol' do
      node = parse(":str")
      expect(node.to_value).to eq :str
    end

    it 'gets for array' do
      node = parse("['str', :str]")
      expect(node.to_value).to eq ['str', :str]
    end
  end

  describe '#to_source' do
    it 'gets for node' do
      source = 'params[:user][:email]'
      instance = double(current_source: source)
      Synvert::Rewriter::Instance.current = instance
      node = parse(source)
      expect(node.to_source).to eq 'params[:user][:email]'
    end
  end

  describe '#indent' do
    it 'gets column number' do
      node = parse('  FactoryGirl.create :post')
      expect(node.indent).to eq 2
    end
  end

  describe '#recursive_children' do
    it 'iterates all children recursively' do
      node = parse('class Synvert; def current_node; @node; end; end')
      children = []
      node.recursive_children { |child| children << child.type }
      expect(children).to be_include :const
      expect(children).to be_include :def
      expect(children).to be_include :args
      expect(children).to be_include :ivar
    end
  end

  describe '#match?' do
    let(:instance) {
      rewriter = Synvert::Rewriter.new('foobar')
      Synvert::Rewriter::Instance.new(rewriter, 'file pattern')
    }
    before { Synvert::Rewriter::Instance.current = instance }

    it 'matches class name' do
      source = 'class Synvert; end'
      instance.current_source = source
      node = parse(source)
      expect(node).to be_match(type: 'class', name: 'Synvert')
    end

    it 'matches message with regexp' do
      source = 'User.find_by_login(login)'
      instance.current_source = source
      node = parse(source)
      expect(node).to be_match(type: 'send', message: /^find_by_/)
    end

    it 'matches arguments with symbol' do
      source = 'params[:user]'
      instance.current_source = source
      node = parse(source)
      expect(node).to be_match(type: 'send', receiver: 'params', message: '[]', arguments: [:user])
    end

    it 'matches assign number' do
      source = 'at_least(0)'
      instance.current_source = source
      node = parse(source)
      expect(node).to be_match(type: 'send', arguments: [0])
    end

    it 'matches arguments with string' do
      source = 'params["user"]'
      instance.current_source = source
      node = parse(source)
      expect(node).to be_match(type: 'send', receiver: 'params', message: '[]', arguments: ['user'])
    end

    it 'matches arguments any' do
      source = 'config.middleware.insert_after ActiveRecord::QueryCache, Lifo::Cache, page_cache: false'
      instance.current_source = source
      node = parse(source)
      expect(node).to be_match(type: 'send', arguments: {any: 'Lifo::Cache'})
    end

    it 'matches not' do
      source = 'class Synvert; end'
      instance.current_source = source
      node = parse(source)
      expect(node).not_to be_match(type: 'class', name: {not: 'Synvert'})
    end
  end
end
