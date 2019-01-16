#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

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

    it "works also when CPE fields contain commas" do
      expect(subject.distro_map("cpe:/o:novell,inc:sles:12,SLES12, Mini edition")).
        to eq({"cpeid" => "cpe:/o:novell,inc:sles:12",
          "name" => "SLES12, Mini edition"})
    end

    it "the number of CPE fields may vary" do
      expect(subject.distro_map("cpe:/o:novell,inc:sles:12:sp5,SLES12 SP5")).
        to eq({"cpeid" => "cpe:/o:novell,inc:sles:12:sp5",
          "name" => "SLES12 SP5"})
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
