#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Instserver"

def fixtures_path(file)
  File.expand_path("../fixtures/#{file}", __FILE__)
end

describe "Yast::InstserverRoutinesInclude" do
  subject do
    instance = Yast::Module.new
    Yast.include instance, "instserver/routines.rb"
    instance
  end
  
  describe "#distro_map" do
    it "returns CPEID and product name" do
      expect(subject.distro_map("cpe:/o:suse:sles:12,SUSE Linux Enterprise Server 12")).
        to eq({"cpeid" => "cpe:/o:suse:sles:12",
          "name" => "SUSE Linux Enterprise Server 12"})
    end

    it "returns product name with comma" do
      expect(subject.distro_map("cpe:/o:suse:sles:12,SLES12, Mini edition")).
        to eq({"cpeid" => "cpe:/o:suse:sles:12",
          "name" => "SLES12, Mini edition"})
    end

    it "returns nil if input is nil" do
      expect(subject.distro_map(nil)).to be_nil
    end

    it "returns nil if input is invalid" do
      expect(subject.distro_map("foo")).to be_nil
    end
  end

  describe "#ReadContentFile" do
    it "returns product LABEL from DISTRO SLES12 content tag" do
      parsed_content = subject.ReadContentFile(fixtures_path("SLES12_content"))
      expect(parsed_content["LABEL"]).to eq("SUSE Linux Enterprise Server 12")
    end

    it "returns product LABEL from SLES11-SP3 content file" do
      parsed_content = subject.ReadContentFile(fixtures_path("SLES11_SP3_content"))
      expect(parsed_content["LABEL"]).to eq("SUSE Linux Enterprise Server 11 SP3")
    end
  end
end
