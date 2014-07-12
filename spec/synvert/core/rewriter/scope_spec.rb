require 'spec_helper'

module Synvert::Core
  describe Rewriter::Scope do
    let(:source) {
"""
describe Post do
  before :each do
    @user = FactoryGirl.create :user
  end

  it 'gets posts' do
    post1 = FactoryGirl.create :post
    post2 = FactoryGirl.create :post
  end
end
"""
    }
    let(:node) { Parser::CurrentRuby.parse(source) }
    let(:instance) { double(:current_node => node, :current_node= => node, :current_source => source) }
    before { Rewriter::Instance.current = instance }

    describe '#process' do
      it 'not call block if no matching node' do
        run = false
        scope = Rewriter::Scope.new instance, type: 'send', message: 'missing' do
          run = true
        end
        scope.process
        expect(run).to be_falsey
      end

      it 'call block if there is matching node' do
        run = false
        scope = Rewriter::Scope.new instance, type: 'send', receiver: 'FactoryGirl', message: 'create', arguments: [':post'] do
          run = true
        end
        scope.process
        expect(run).to be_truthy
      end
    end
  end
end
