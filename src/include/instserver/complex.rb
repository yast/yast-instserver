# encoding: utf-8

# File:	include/instserver/complex.ycp
# Package:	Configuration of instserver
# Summary:	Dialogs definitions
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  module InstserverComplexInclude
    def initialize_instserver_complex(include_target)
      Yast.import "UI"

      textdomain "instserver"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "WizardHW"
      Yast.import "Instserver"

      Yast.include include_target, "instserver/helps.rb"

      # selected repository
      @selected_source = ""
    end

    # Return a modification status
    # @return true if data was modified
    def Modified
      Instserver.Modified
    end

    def ReallyAbort
      !Instserver.Modified || Popup.ReallyAbort(true)
    end

    def PollAbort
      UI.PollInput == :abort
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "read", ""))
      # Instserver::AbortFunction = PollAbort;
      ret = Instserver.Read

      ret ? Instserver.FirstDialog == "settings" ? :setup : :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "write", ""))

      # Instserver::AbortFunction = PollAbort;
      ret = Instserver.Write
      ret ? :next : :abort
    end


    def createOverviewTable
      conf = deep_copy(Instserver.Configs)

      Builtins.y2milestone("Current configuration: conf: %1", conf)

      ret = []

      if conf != nil && Ops.greater_than(Builtins.size(conf), 0)
        Builtins.foreach(conf) do |name, cfg|
          descr = []
          if Builtins.haskey(cfg, "LABEL") &&
              Ops.get_string(cfg, "LABEL", "") != nil
            # repository overview - %1 is product name (e.g. "SUSE LINUX Version 10.0")
            descr = Builtins.add(
              descr,
              Builtins.sformat(_("Label: %1"), Ops.get_string(cfg, "LABEL", ""))
            )
          end
          if Builtins.haskey(cfg, "slp") &&
              Ops.get_boolean(cfg, "slp", false) != nil
            # yes/no string displayed in the overview
            descr = Builtins.add(
              descr,
              Builtins.sformat(
                _("Announce Using SLP: %1"),
                Ops.get_boolean(cfg, "slp", false) ? _("Yes") : _("No")
              )
            )
          end
          product_name = Ops.get_string(cfg, "PRODUCT", "")
          if product_name == ""
            # code11
            product_name = Ops.get_string(cfg, "NAME", "")
          end
          r = {
            "id"          => name,
            "table_descr" => [
              name,
              Ops.add(
                Ops.add(product_name, " "),
                Ops.get_string(cfg, "VERSION", "")
              )
            ],
            "rich_descr"  => WizardHW.CreateRichTextDescription(name, descr)
          }
          ret = Builtins.add(ret, r)
        end
      end

      deep_copy(ret)
    end

    # Overview dialog
    # @return dialog result
    def OverviewDialog
      # Instserver overview dialog caption
      caption = _("Installation Server")
      extra_buttons = [
        # menu item
        [:config, _("&Server Configuration...")]
      ]
      items = createOverviewTable

      WizardHW.CreateHWDialog(
        caption,
        Ops.get_string(@HELPS, "overview", ""),
        # table header
        [_("Configuration"), _("Product")],
        extra_buttons
      )

      WizardHW.SetContents(items)

      Wizard.SetNextButton(:next, Label.FinishButton)


      ret = nil
      while true
        # initilize selected selected repository
        @selected_source = WizardHW.SelectedItem if @selected_source == ""

        # set previously selected repository
        WizardHW.SetSelectedItem(@selected_source)


        ev = WizardHW.WaitForEvent
        Builtins.y2milestone("WaitForEvent: %1", ev)

        ret = Ops.get_symbol(ev, ["event", "ID"])
        current = Ops.get_string(ev, "selected", "")
        @selected_source = WizardHW.SelectedItem

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        # add
        elsif ret == :add
          Instserver.Config = {}
          break
        # edit
        elsif ret == :edit
          Instserver.Config = Ops.get(Instserver.Configs, current, {})
          break
        # delete
        elsif ret == :delete
          Builtins.y2milestone("Deleting: %1", current)
          Instserver.Configs = Builtins.filter(Instserver.Configs) do |k, v|
            k != current
          end
          Instserver.to_delete = Builtins.add(Instserver.to_delete, current)

          # refresh content of the table
          items = createOverviewTable
          WizardHW.SetContents(items)
          WizardHW.SetSelectedItem("")

          # the selected repository has just been removed
          @selected_source = ""

          next
        elsif ret == :next || ret == :back || ret == :config
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      deep_copy(ret)
    end
  end
end
