#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Instserver"

describe "Yast::Instserver" do
  subject { Yast::Instserver }
  
  describe "#Modified" do
    it "returns false initially" do
      expect(subject.Modified).to be_false
    end
  end

  describe "#EscapeSLPData" do
    it "does not escape normal characters" do
      input = { "description" => "No need to escape anything." }
      expect(subject.EscapeSLPData(input)).to eq(input)
    end
    
    it "escapes SLP reserved characters (()<>=!#,;\\) in values" do
      input = { "description" => "must be escaped: ()<>=!#,;\\" }
      result = { "description" => "must be escaped: \\28\\29\\3c\\3e\\3d\\21\\23\\2c\\3b\\5c" }
      expect(subject.EscapeSLPData(input)).to eq(result)
    end
    
    it "escapes SLP reserved characters (.=%:\\) in keys" do
      input = { "escaped.=name" => "value" }
      result = { "escaped\\2e\\3dname" => "value" }
      expect(subject.EscapeSLPData(input)).to eq(result)
    end
  end
end
