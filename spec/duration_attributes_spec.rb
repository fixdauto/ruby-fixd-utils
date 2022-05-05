# frozen_string_literal: true

require "spec_helper"
require "active_model"

RSpec.describe DurationAttributes do
  before do
    stub_const("DurationAttributeTest", Class.new do
      include ActiveModel::Model
      include DurationAttributes
      attr_accessor :trial_period_seconds

      duration_attribute :trial_period
    end)
  end

  let(:test_obj) { DurationAttributeTest.new(trial_period_seconds: 60) }

  it "should allow reading the value as a duration" do
    expect(test_obj.trial_period).to eq 1.minute
  end

  it "should allow setting the value to null" do
    test_obj.trial_period = nil
    expect(test_obj.trial_period).to be_nil
    expect(test_obj.trial_period_seconds).to be_nil
  end

  context "using duration" do
    before { test_obj.trial_period = 1.year }

    it "should update the duration" do
      expect(test_obj.trial_period).to eq 1.year
    end

    it "should update the underlying value" do
      expect(test_obj.trial_period_seconds).to eq 31_556_952
    end
  end

  context "using ISO 8601 duration strings" do
    before { test_obj.trial_period = "P3M" }

    it "should update the duration" do
      expect(test_obj.trial_period).to eq 3.months
    end

    it "should update the underlying value" do
      expect(test_obj.trial_period_seconds).to eq 7_889_238
    end
  end

  context "alternate units" do
    before do
      stub_const("DurationAttributeUnitTest", Class.new do
        include ActiveModel::Model
        include DurationAttributes
        attr_accessor :trial_period_days

        duration_attribute :trial_period, unit: :days
      end)
    end

    let(:test_obj) { DurationAttributeUnitTest.new(trial_period_days: 30) }

    it "should use the specified units" do
      expect(test_obj.trial_period_days).to eq 30
      expect(test_obj.trial_period).to eq 30.days
    end

    let(:other_units) { 4.weeks + 10.days + 48.hours }

    it "should convert durations to the specified units" do
      test_obj.trial_period = other_units

      expect(test_obj.trial_period).to eq 40.days
      expect(test_obj.trial_period_days).to eq 40
    end
  end

  describe "use_build" do
    context "false" do
      let(:test_obj) do
        Class.new do
          include ActiveModel::Model
          include DurationAttributes
          attr_accessor :trial_period_seconds

          duration_attribute :trial_period, unit: :seconds, use_build: false
        end.new(trial_period: 1.year)
      end

      it "should keep durations in their units" do
        expect(test_obj.trial_period.parts).to eq({ seconds: 31_556_952 })
      end
    end

    context "true" do
      let(:test_obj) do
        Class.new do
          include ActiveModel::Model
          include DurationAttributes
          attr_accessor :trial_period_seconds

          duration_attribute :trial_period, unit: :seconds, use_build: true
        end.new(trial_period: 1.year)
      end

      it "should optimize the units to the most efficient form" do
        expect(test_obj.trial_period.parts).to eq({ years: 1 })

        test_obj.trial_period_seconds = 2_595_600
        expect(test_obj.trial_period.parts).to eq({ weeks: 4, days: 2, hours: 1 })
      end
    end
  end
end
