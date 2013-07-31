# encoding: utf-8

# File:	include/instserver/wizards.ycp
# Package:	Configuration of instserver
# Summary:	Wizards definitions
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  module InstserverWizardsInclude
    def initialize_instserver_wizards(include_target)
      Yast.import "UI"

      textdomain "instserver"

      Yast.import "Sequencer"
      Yast.import "Instserver"
      Yast.import "Wizard"

      Yast.include include_target, "instserver/complex.rb"
      Yast.include include_target, "instserver/dialogs.rb"
    end

    # Add a configuration of instserver
    # @return sequence result
    def AddSequence
      aliases = { "sourceconfig" => lambda { SourceConfigDialog() }, "mediaconfig" => lambda(
      ) do
        MediaDialog()
      end }

      sequence = {
        "ws_start"     => "sourceconfig",
        "sourceconfig" => { :abort => :abort, :next => "mediaconfig" },
        "mediaconfig"  => { :abort => :abort, :next => :next }
      }

      Sequencer.Run(aliases, sequence)
    end


    def EditSequence
      aliases = { "sourceconfig" => lambda { SourceConfigDialog() } }

      sequence = {
        "ws_start"     => "sourceconfig",
        "sourceconfig" => { :abort => :abort, :next => :next }
      }

      Sequencer.Run(aliases, sequence)
    end

    # Server Sequence
    # @return sequence result
    def ServerSequence
      aliases = {
        "main" => lambda { ServerDialog() },
        "nfs"  => lambda { NfsDialog() },
        "http" => lambda { HttpDialog() },
        "ftp"  => lambda { FtpDialog() }
      }

      sequence = {
        "ws_start" => "main",
        "main"     => {
          :abort => :abort,
          :nfs   => "nfs",
          :http  => "http",
          :ftp   => "ftp",
          :next  => :next
        },
        "ftp"      => { :abort => :abort, :next => :next },
        "http"     => { :abort => :abort, :next => :next },
        "nfs"      => { :abort => :abort, :next => :next }
      }

      Sequencer.Run(aliases, sequence)
    end




    # Main workflow of the instserver configuration
    # @return sequence result
    def MainSequence
      aliases = {
        "overview" => lambda { OverviewDialog() },
        "add"      => [lambda { AddSequence() }, true],
        "edit"     => [lambda { EditSequence() }, true],
        "server"   => [lambda { ServerSequence() }, true]
      }

      start = Instserver.FirstDialog

      sequence = {
        "ws_start" => "overview",
        "overview" => {
          :abort  => :abort,
          :next   => :next,
          :add    => "add",
          :edit   => "edit",
          :config => "server"
        },
        "server"   => { :abort => :abort, :next => "overview" },
        "add"      => { :abort => :abort, :next => "overview" },
        "edit"     => { :abort => :abort, :next => "overview" }
      }

      ret = Sequencer.Run(aliases, sequence)

      deep_copy(ret)
    end

    # Whole configuration of instserver
    # @return sequence result
    def InstserverSequence
      aliases = {
        "read"  => [lambda { ReadDialog() }, true],
        "main"  => lambda { MainSequence() },
        "setup" => lambda { ServerSequence() },
        "write" => lambda { WriteDialog() }
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :setup => "setup", :next => "main" },
        "setup"    => { :next => "main", :abort => :abort },
        "main"     => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("instserver")

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      deep_copy(ret)
    end
  end
end
