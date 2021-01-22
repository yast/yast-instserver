#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Instserver"

describe "Yast::Instserver" do
  subject { Yast::Instserver }

  describe "#SetupNFS" do
    let(:nfs_service_status) { 0 }

    before do
      allow(Yast::Package).to receive(:InstallAll).and_return(true)
      allow(Yast::Ops).to receive(:greater_than).and_return(false)
      allow(Yast::Service).to receive(:Enable)
      allow(Yast::Service).to receive(:Reload)
      allow(Yast::Service).to receive(:Start)
      allow(Yast::Service).to receive(:Status).with("nfs-server").and_return(nfs_service_status)
      allow(Y2Firewall::Firewalld).to receive(:read)
      allow(Y2Firewall::Firewalld).to receive(:write)
    end

    it "enables nfs-server service" do
      expect(Yast::Service).to receive(:Enable).with("nfs-server")

      subject.SetupNFS("/tmp", {})
    end

    context "when nfs-service is already active" do
      let(:nfs_service_status) { 0 }

      it "reload it" do
        expect(Yast::Service).to receive(:Reload).with("nfs-server")

        subject.SetupNFS("/tmp", {})
      end
    end

    context "when nfs-service is not active yet" do
      let(:nfs_service_status) { -1 }

      it "start it" do
        expect(Yast::Service).to receive(:Start).with("nfs-server")

        subject.SetupNFS("/tmp", {})
      end
    end
  end

  describe "#Modified" do
    it "returns false initially" do
      expect(subject.Modified).to eq false
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
