# encoding: utf-8

# File:	clients/instserver.ycp
# Package:	Configuration of instserver
# Summary:	Main file
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
#
# Main file for instserver configuration. Uses all other files.
module Yast
  class InstserverClient < Client
    def main
      Yast.import "UI"

      #**
      # <h3>Configuration of instserver</h3>

      textdomain "instserver"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Instserver module started")

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"
      Yast.import "CommandLine"

      Yast.include self, "instserver/wizards.rb"
      # is this proposal or not?
      @test = false
      @args = WFM.Args
      if Ops.greater_than(Builtins.size(@args), 0)
        if Ops.is_path?(WFM.Args(0)) && WFM.Args(0) == path(".test")
          Builtins.y2milestone("Using PROPOSE mode")
          @test = true
        end
      end

      @cmdline_description = {
        "id"         => "instserver",
        "guihandler" => fun_ref(method(:InstserverSequence), "any ()")
      }

      @ret = CommandLine.Run(@cmdline_description)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Instserver module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::InstserverClient.new.main
