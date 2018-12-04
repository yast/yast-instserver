# encoding: utf-8

# File:	include/instserver/dialogs.rb
# Package:	Configuration of instserver
# Summary:	Dialogs definitions
# Authors:	Anas Nashif <nashif@suse.de>
#

require "fileutils"
require "shellwords"

module Yast
  module InstserverDialogsInclude
    def initialize_instserver_dialogs(include_target)
      Yast.import "UI"

      textdomain "instserver"

      Yast.import "Installation"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Instserver"
      Yast.import "CWMFirewallInterfaces"
      Yast.import "String"
      Yast.import "Report"

      Yast.include include_target, "instserver/helps.rb"
      Yast.include include_target, "instserver/routines.rb"
      Yast.include include_target, "instserver/complex.rb"
    end

    # CD Popup
    # @param string popup message
    # @param boolean true if ISO
    # @return [Object]
    def CDPopup(msg, iso)
      if iso
        f = UI.AskForExistingFile(
          Ops.get_string(Instserver.ServerSettings, "iso-dir", ""),
          "*.iso",
          msg
        )
        Builtins.y2milestone("file: %1", f)
        if f != nil
          return deep_copy(f)
        else
          return ""
        end
      else
        pop = Popup.AnyQuestion3(
          _("Change Media"),
          msg,
          Label.ContinueButton, # `yes
          Label.CancelButton, # `no
          Label.SkipButton, # `retry
          :focus_yes
        )
        if pop == :no
          return :abort
        elsif pop == :retry
          Builtins.y2debug("skipping media")
          return :skip
        end
      end

      nil
    end

    def LinkTarget(source)
      ret = ""

      command = "/usr/bin/ls -l #{source.shellescape}"
      res = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      out = Builtins.splitstring(Ops.get_string(res, "stdout", ""), "\n")

      if Ops.greater_than(Builtins.size(out), 0)
        line = Ops.get(out, 0, "")

        ret = Builtins.regexpsub(line, "^l.* -> (.*)", "\\1")
      end

      Builtins.y2milestone("Target of %1: %2", source, ret)

      ret
    end

    def IsBaseProduct(content, cont_file)
      content = deep_copy(content)
      ret = false
      basecontent = ReadContentFile(cont_file)

      Builtins.y2milestone("using content file: %1", cont_file)
      Builtins.y2milestone("content: %1", content)
      Builtins.y2milestone("basecontent: %1", basecontent)

      basecontent = {} if basecontent == nil

      if Builtins.tolower(Ops.get_string(content, "BASEPRODUCT", "")) ==
          Builtins.tolower(Ops.get_string(basecontent, "BASEPRODUCT", "")) &&
          Ops.get_string(content, "BASEVERSION", "") ==
            Ops.get_string(basecontent, "BASEVERSION", "") ||
          # or it's a service pack for maintained product (e.g. NLD)
          # compare BASEPRODUCT and PRODUCT in that case
          !Builtins.haskey(basecontent, "BASEPRODUCT") &&
            !Builtins.haskey(basecontent, "BASEVERSION") &&
            Builtins.tolower(Ops.get_string(content, "BASEPRODUCT", "")) ==
              Builtins.tolower(Ops.get_string(basecontent, "PRODUCT", "")) &&
            Ops.get_string(content, "BASEVERSION", "") ==
              Ops.get_string(basecontent, "VERSION", "")
        # Same base product => OK
        ret = true
        Builtins.y2milestone("found matching base product")
      end

      ret
    end


    # see http://en.opensuse.org/Standards/YaST2_Repository_Metadata/content
    def code10(content_file)
      content_file = deep_copy(content_file)
      # ask for an addon only when the product is pre-CODE10
      ret = true

      product_lower = Builtins.tolower(
        Ops.get_string(content_file, "PRODUCT", "")
      )
      if product_lower == ""
        # code11
        product_lower = Builtins.tolower(
          Ops.get_string(content_file, "NAME", "")
        )
      end

      version_str = Ops.get_string(content_file, "VERSION", "")

      Builtins.y2milestone("product: %1", product_lower)
      Builtins.y2milestone("version: %1", version_str)

      version_major = 0
      version_minor = 0

      if Builtins.issubstring(version_str, ".")
        parts = Builtins.splitstring(version_str, ".")

        version_major = Builtins.tointeger(Ops.get(parts, 0, "0"))
        version_minor = Builtins.tointeger(Ops.get(parts, 1, "0"))
      else
        version_major = Builtins.tointeger(version_str)
      end

      if version_major == nil
        Builtins.y2warning("version_major is nil, setting to 0")
        version_major = 0
      end

      if version_minor == nil
        Builtins.y2warning("version_minor is nil, setting to 0")
        version_minor = 0
      end

      Builtins.y2milestone("major version number: %1", version_major)
      Builtins.y2milestone("minor version number: %1", version_minor)

      version = Ops.add(Ops.multiply(100, version_major), version_minor)
      Builtins.y2milestone("version: %1", version)

      # SUSE Linux <= 10.0
      if product_lower == "suse linux" && Ops.less_or_equal(version, 1000) ||
          # SLES or CORE == 9
          (product_lower == "suse sles" || product_lower == "suse core") &&
            version == 900 ||
          product_lower == "suse sles 9 service-pack" ||
          product_lower == "open enterprise server" && version == 0 ||
          product_lower == "suse sles" && Ops.less_or_equal(version, 800)
        ret = false
      end

      Builtins.y2milestone("CODE10 product: %1", ret)

      ret
    end



    # Copy CDs to local disk
    # @param string directory
    # @param symbol source type
    # @param boolean true if copying using ISO files
    # @param boolean prompt for additional CDs.
    # @return [Object]
    def CopyCDs(dir, stype, iso, promptmore, cddrive)
      # free mount point
      SCR.Execute(path(".target.umount"), Installation.sourcedir)

      default_device = cddrive
      mount_options = iso ? "-oloop,ro " : ""

      # CD is mounted. Check contents.
      cdpath = Installation.sourcedir

      current_cd = 1
      total_cds = 1
      standalone = true
      standalone_product = true
      baseproduct = false
      base = ""
      basever = ""
      prompt_string = ""
      prompt_totalcds = 0
      medianames = []
      failed = false
      cds_copied = false
      code10_source = false

      media_id = ""

      restart = false

      pop = :none

      # content file at first CD must be preserved (#171157)
      content_first_CD = ""

      # Loop for all CDs
      while true
        msg = ""
        if !baseproduct && standalone && Builtins.size(medianames) == 0
          # %1 is the current cd number
          if !iso
            msg = Builtins.sformat(
              _("Insert CD %1 then press continue."),
              current_cd
            )
          else
            msg = Builtins.sformat(
              _("Select ISO image %1 then press continue."),
              current_cd
            )
          end
        else
          # %2 is the product name and version
          cd_prompt = _("Insert CD %1 of %2.")
          iso_prompt = _("Select ISO image %1 of %2.")
          prompt_for_cd = 0

          if promptmore || !standalone && !baseproduct && !restart
            prompt_for_cd = current_cd
          else
            prompt_for_cd = Ops.add(prompt_totalcds, current_cd)
          end

          if !iso
            if Builtins.size(medianames) == 0
              msg = Builtins.sformat(cd_prompt, prompt_for_cd, prompt_string)
            else
              m = ""
              Builtins.y2milestone(
                "medianames: %1, totalcds: %2",
                Builtins.size(medianames),
                total_cds
              )
              if Ops.greater_than(Builtins.size(medianames), 1)
                Builtins.y2milestone("all media names available")
                m = Ops.get_string(
                  medianames,
                  Ops.subtract(prompt_for_cd, 1),
                  ""
                )
              else
                prompt_string = Builtins.substring(
                  Builtins.regexpsub(
                    Ops.get_string(medianames, 0, ""),
                    "(.*)CD.",
                    "\\1CD%1"
                  ),
                  7,
                  Builtins.size(Ops.get_string(medianames, 0, ""))
                )
                m = Builtins.sformat(prompt_string, prompt_for_cd)
              end
              # popup request, %1 is CD medium name
              msg = Builtins.sformat(_("Insert\n%1"), m)
            end
          else
            if Builtins.size(medianames) == 0
              msg = Builtins.sformat(iso_prompt, prompt_for_cd, prompt_string)
            else
              m = ""
              Builtins.y2milestone(
                "medianames: %1, totalcds: %2",
                Builtins.size(medianames),
                total_cds
              )
              if Ops.greater_than(Builtins.size(medianames), 1)
                Builtins.y2milestone("all media names available")
                m = Ops.get_string(
                  medianames,
                  Ops.subtract(prompt_for_cd, 1),
                  ""
                )
              else
                prompt_string = Builtins.regexpsub(
                  Ops.get_string(medianames, 0, ""),
                  "(.*)CD.",
                  "\\1CD%1"
                )
                Builtins.y2debug("prompt string: %1)", prompt_string)
                m = Builtins.sformat(prompt_string, prompt_for_cd)
              end
              # popup request, %1 is ISO name
              msg = Builtins.sformat(_("Select %1"), m)
            end
          end
        end


        if iso
          default_device = Convert.to_string(CDPopup(msg, iso))
          if default_device == ""
            Builtins.y2debug(
              "total_cds: %1, current_cd: %2",
              total_cds,
              current_cd
            )
            if total_cds == current_cd
              failed = !cds_copied
              break
            else
              current_cd = Ops.add(current_cd, 1)
              next
            end
          end
        else
          pop = Convert.to_symbol(CDPopup(msg, iso))
          if pop == :skip
            if total_cds == current_cd
              break
            else
              current_cd = Ops.add(current_cd, 1)
              next
            end
          elsif pop == :abort
            return :abort
          end
        end

        # make sure the mount point exists
        if !File.exist?(Installation.sourcedir)
          ::FileUtils.mkdir_p(Installation.sourcedir)
        end

        # try to mount device
        if SCR.Execute(
            path(".target.mount"),
            [default_device, Installation.sourcedir],
            mount_options
          ) == false
          # cant mount /dev/cdrom popup
          Builtins.y2error("mount faild")
          next
        end
        Builtins.y2debug("mounted cdrom")

        media = ReadMediaFile(
          Builtins.sformat("%1/media.%2/media", cdpath, current_cd)
        )
        Builtins.y2milestone("media: %1", media)
        content = {}

        # remove empty string at the end if it's present
        if Ops.greater_or_equal(Builtins.size(media), 1) &&
            Ops.get(media, Ops.subtract(Builtins.size(media), 1)) == ""
          media = Builtins.remove(media, Ops.subtract(Builtins.size(media), 1))
          Builtins.y2milestone("media: %1", media)
        end

        if Builtins.size(media) == 0 ||
            media_id != Ops.get(media, 1, "") && media_id != ""
          Builtins.y2warning("wrong CD or non suse CD")
          SCR.Execute(path(".target.umount"), Installation.sourcedir)
          next
        else
          # media names at the end of file
          if Builtins.tointeger(Ops.get(media, 2, "-1")) == nil &&
              Ops.greater_than(Builtins.size(media), 3)
            Ops.set(
              media,
              2,
              Builtins.sformat("%1", Ops.subtract(Builtins.size(media), 2))
            )
            Builtins.y2milestone(
              "Setting media number to %1",
              Ops.get(media, 2)
            )
          end

          content_path = File.join(cdpath, "content")
          content = ReadContentFile(content_path) if File.exist?(content_path)
          Builtins.y2milestone("Content file: %1", content)
          # don't rewrite the already read content file,
          # content file from CORE9 would rewrite already read file from SLES9
          if current_cd == 1 && content_first_CD == ""
            Builtins.y2milestone(
              "Reading content file %1",
              content_path
            )
            content_first_CD = File.read(content_path) if File.exist?(content_path)
            Builtins.y2debug("content file: %1", content_first_CD)
          end
          if Ops.get(media, 2, "") != "" &&
              Ops.get(media, 2, "") != "doublesided"
            total_cds = Builtins.tointeger(Ops.get(media, 2, "-1"))
            Builtins.y2milestone("total_cds: %1", total_cds)
            media_id = Ops.get(media, 1, "")
          end

          Builtins.y2debug("base: %1 basever: %2", base, basever)

          # Bug 47599: CD2 of SP1 not copied
          if Ops.get_string(content, "PRODUCT", "dummy") != base &&
              Ops.get_string(content, "VERSION", "dummy") != basever &&
              !standalone
            #  Check if this CD set is based on the base product (CORE)
            if Ops.get_string(content, "BASEPRODUCT", "dummy") != base &&
                Ops.get_string(content, "BASEVERSION", "dummy") != basever
              SCR.Execute(path(".target.umount"), Installation.sourcedir)
              next
            end
          end

          Builtins.foreach(media) do |medium|
            if Builtins.substring(medium, 0, 5) == "MEDIA"
              medium = Builtins.substring(medium, 7)

              if !Builtins.contains(medianames, medium)
                medianames = Builtins.add(medianames, medium)
              end
            end
          end
          Builtins.y2milestone("medianames: %1", medianames)
        end


        distprod = Ops.get_string(content, "LABEL", "")
        flags = Ops.get_string(content, "FLAGS", "")
        flaglist = Builtins.splitstring(flags, " ")

        # Detect SP
        if Builtins.contains(flaglist, "SP")
          Instserver.is_service_pack = true
        else
          Instserver.is_service_pack = false
        end

        Builtins.y2milestone(
          "Service Pack detected: %1",
          Instserver.is_service_pack
        )

        l = Builtins.splitstring(distprod, " ")
        distprod = Builtins.mergestring(l, "-")
        tgt = Builtins.sformat("%1/%2/CD%3", dir, distprod, current_cd)
        Builtins.y2milestone("tgt: %1", tgt)

        cmds = []

        # Copy stuff here.
        # Now, we check if this product on the CD is based on some other product. If
        # yes, then it will be copied into  a sub-directory and not in the requested
        # root.

        code10_source = code10(content)
        Builtins.y2milestone("CODE10 repository: %1", code10_source)

        # This product is based on some other product
        if Builtins.tolower(Ops.get_string(content, "BASEPRODUCT", "")) != "" &&
            Ops.get_string(content, "BASEVERSION", "") != ""
          Builtins.y2milestone("products: %1", Instserver.products)
          Builtins.y2milestone(
            "product require base product: %1, version: %2",
            Ops.get_string(content, "BASEPRODUCT", ""),
            Ops.get_string(content, "BASEVERSION", "")
          )

          found = false
          Builtins.foreach(Instserver.products) do |prod|
            if !found
              cont_file = Ops.add(
                Ops.add(Ops.add(dir, "/"), Ops.get_string(prod, "name", "")),
                "/content"
              )
              if Ops.less_than(SCR.Read(path(".target.size"), cont_file), 0)
                cont_file = Ops.add(
                  Ops.add(Ops.add(dir, "/"), Ops.get_string(prod, "name", "")),
                  "/CD1/content"
                )
              end

              found = true if IsBaseProduct(content, cont_file)
            end
          end


          if !found &&
              Ops.greater_or_equal(
                SCR.Read(
                  path(".target.size"),
                  Ops.add(Installation.sourcedir, "/yast")
                ),
                0
              )
            # check also subdirectories
            yast_subdir = File.join(Installation.sourcedir, "yast")
            cmd = "cd #{yast_subdir.shellescape}; /usr/bin/find -maxdepth 1 -type d",
            Builtins.y2milestone("find command: %1", cmd)
            out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

            dirs = Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")

            # remove unusable items
            dirs = Builtins.filter(dirs) { |d| d != "." && d != "" }
            Builtins.y2milestone("found product subdirectories: %1", dirs)

            Builtins.foreach(dirs) do |d|
              cont_file = File.join(yast_subdir, d, "content")
              Builtins.y2milestone("Trying content file: %1", cont_file)
              found = true if IsBaseProduct(content, cont_file)
            end
          end

          if !found
            # try to search in the base directory (NLD9 workaround)
            cont_file = Ops.add(Installation.sourcedir, "/content")

            if IsBaseProduct(content, cont_file)
              found = true
              Builtins.y2milestone(
                "Base product has been found in the base direcory (file %1)",
                cont_file
              )
            end
          end

          Builtins.y2milestone("products; %1", Instserver.products)

          # code10 add-on is a standalone repository
          if !found && !code10_source
            # add-on medium (e.g. service pack) doesn't match configured repository
            Report.LongError(
              Builtins.sformat(
                _(
                  "The medium requires product %1, which is not provided\n" +
                    "by the current repository.\n" +
                    "\n" +
                    "Select the base product medium first."
                ),
                Ops.get_string(content, "BASEPRODUCT", "")
              )
            )
            media_id = ""
            medianames = []
            next
          end

          base = Ops.get_string(content, "BASEPRODUCT", "") # i.e. SUSE CORE
          basever = Ops.get_string(content, "BASEVERSION", "") # i.e. 9


          # code10 is always standalone product
          standalone = code10_source
          # remember for the finalizing
          standalone_product = code10_source

          if code10_source
            if total_cds == 1
              tgt = Builtins.sformat("%1/", dir)
            else
              tgt = Builtins.sformat("%1/CD%2", dir, current_cd)
            end
          end

          Builtins.y2milestone("tgt: %1", tgt)
          SCR.Execute(path(".target.mkdir"), tgt)
          Builtins.y2debug(
            "config=%1, products=%2",
            Instserver.Config,
            Instserver.products
          )

          # and its not a base product
          baseproduct = false

          # No media names, so we have to create the string for media request
          if Builtins.size(medianames) == 0
            prompt_string = Ops.get_string(content, "LABEL", "")
          end

          prompt_totalcds = total_cds

          if current_cd == 1
            proddata = {
              "standalone"  => false,
              "baseproduct" => false,
              "name"        => distprod,
              "SP"          => Instserver.is_service_pack
            }
            Instserver.products = Builtins.add(Instserver.products, proddata)
          end

          # Create product dir
          SCR.Execute(path(".target.mkdir"), tgt)
          Builtins.y2debug(
            "config=%1, products=%2",
            Instserver.Config,
            Instserver.products
          )
        elsif Ops.get_string(content, "PRODUCT", "dummy") == base &&
            Ops.get_string(content, "VERSION", "dummy") == basever
          Builtins.y2milestone("Product is base.")
          if current_cd == 1
            proddata = {
              "standalone"  => true,
              "baseproduct" => true,
              "name"        => distprod,
              "SP"          => Instserver.is_service_pack
            }
            Instserver.products = Builtins.add(Instserver.products, proddata)
          end
          standalone = true
          baseproduct = true
          SCR.Execute(path(".target.mkdir"), tgt)
          Builtins.y2debug(
            "config=%1, products=%2",
            Instserver.Config,
            Instserver.products
          )
        else
          Builtins.y2milestone("")
          if current_cd == 1
            proddata = {
              "standalone"  => true,
              "baseproduct" => true,
              "name"        => distprod,
              "SP"          => Instserver.is_service_pack
            }
            Instserver.products = Builtins.add(Instserver.products, proddata)
          end
          standalone = true
          baseproduct = true
          if Builtins.size(medianames) == 0
            prompt_string = Ops.get_string(content, "LABEL", "")
          end
          # else, we create CD1, CD2, etc. (for code10 always)
          if stype == :onedir && !code10_source
            tgt = Builtins.sformat("%1/", dir)
          else
            tgt = Builtins.sformat("%1/CD%2", dir, current_cd)
          end
          Builtins.y2milestone("tgt: %1", tgt)
          SCR.Execute(path(".target.mkdir"), tgt)
          Builtins.y2debug(
            "config=%1, products=%2",
            Instserver.Config,
            Instserver.products
          )
        end

        Popup.ShowFeedback(
          _("Copying CD contents to local directory"),
          _("This may take a while...")
        )

        # Do actual copying of data
        if Instserver.test
          cmds = Builtins.add(
            cmds,
            Builtins.sformat("/usr/bin/cp -pR %1/media.%2 %3", cdpath.shellescape, current_cd.shellescape, tgt.shellescape)
          )
          cmds = Builtins.add(
            cmds,
            Builtins.sformat("/usr/bin/cp  %1/content %2", cdpath.shellescape, tgt.shellescape)
          )
        else
          cmds = Builtins.add(
            cmds,
            Builtins.sformat(
              "cd %1 && /usr/bin/tar cf - . | (cd %2  && /usr/bin/tar xBf -)",
              cdpath.shellescape,
              tgt.shellescape
            )
          )
        end


        files = []
        # Link files
        if !standalone && current_cd == 1
          if promptmore
            files = ["driverupdate", "linux"]
          else
            files = ["control.xml", "content", "media.1", "boot"]
          end
          cmds = Convert.convert(
            Builtins.union(cmds, Instserver.createLinks(dir, distprod, files)),
            :from => "list",
            :to   => "list <string>"
          )
        end

        if Ops.greater_than(Builtins.size(cmds), 0)
          aborted = false

          Builtins.foreach(cmds) do |cmd|
            Builtins.y2milestone("executing command: %1", cmd)
            res = Convert.to_integer(SCR.Execute(path(".target.bash"), cmd))
            if res != 0
              Builtins.y2milestone(
                "aborting: command %1 failed, exit=%2",
                cmd,
                res
              )

              # close the progress popup
              Popup.ClearFeedback

              # TODO: report more details (stderr)
              Report.Error(_("Error while moving repository content."))
              aborted = true

              raise Break
            end
          end

          if aborted
            # unmount the repository
            SCR.Execute(path(".target.umount"), Installation.sourcedir)
            return :abort
          end

          cmds = []
          cds_copied = true
        end

        # check if there is a new rescue image on the first additional CD
        if promptmore && current_cd == 1 &&
            Ops.greater_than(
              SCR.Read(path(".target.size"), Ops.add(tgt, "/boot")),
              0
            ) &&
            Ops.add(dir, "/") != tgt
          Builtins.y2milestone("Found new 'boot' directory")

          # workaround for flat directory structure (NLD9) - preserve the original content
          move = Builtins.sformat(
            "cd %1; /usr/bin/test -d boot -a ! -L boot && /usr/bin/mv -b boot boot.old && /usr/bin/ln -s boot.old boot",
            dir.shellescape
          )
          SCR.Execute(path(".target.bash"), move)

          # remember the old "root" file (parse the link)
          linktgt = LinkTarget(Ops.add(dir, "/boot"))
          Builtins.y2milestone("link target: %1", linktgt)

          # remove the old "boot" link
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("/usr/bin/rm -rf %1/boot", dir.shellescape)
          )

          # if there are "root" and "rescue" images both then just create a new link
          if Ops.greater_than(
              SCR.Read(path(".target.size"), Ops.add(tgt, "/boot/rescue")),
              0
            ) &&
              Ops.greater_than(
                SCR.Read(path(".target.size"), Ops.add(tgt, "/boot/root")),
                0
              )
            files = ["boot"]
            cmds = Convert.convert(
              Builtins.union(cmds, Instserver.createLinks(dir, distprod, files)),
              :from => "list",
              :to   => "list <string>"
            )
            Builtins.foreach(cmds) do |cmd|
              Builtins.y2debug("executing command: %1", cmd)
              SCR.Execute(path(".target.bash"), cmd)
            end
            cmds = []
          else
            mkdir = Builtins.sformat("/usr/bin/mkdir %1/boot", dir.shellescape)
            SCR.Execute(path(".target.bash"), mkdir)

            relprod = Builtins.substring(tgt, Ops.add(Builtins.size(dir), 1))
            Builtins.y2milestone("relative target: %1", relprod)

            # link the new content there (link every file/directory)
            linkcommand = Builtins.sformat(
              "cd %1/boot; /usr/bin/ln -s ../%2/boot/* .",
              dir.shellescape,
              relprod.shellescape
            )
            SCR.Execute(path(".target.bash"), linkcommand)

            # add missing links from the original product
            linkcommand = Builtins.sformat(
              "cd %1/boot; /usr/bin/ln -s ../%2/* .",
              dir.shellescape,
              linktgt.shellescape
            )
            SCR.Execute(path(".target.bash"), linkcommand)

            # recreate the index file
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat(
                "/usr/bin/rm -f %1/boot/directory.yast; cd %1/boot; /usr/bin/ls | /usr/bin/grep -v -e '^\\.$' -e '^\\.\\.$' > %1/boot/directory.yast",
                dir.shellescape
              )
            )
          end
        end


        Popup.ClearFeedback

        SCR.Execute(path(".target.umount"), Installation.sourcedir)

        Builtins.y2milestone(
          "total_cds: %1, current_cd: %2, standalone: %3, baseproduct: %4, promptmore: %5, is_service_pack: %6",
          total_cds,
          current_cd,
          standalone,
          baseproduct,
          promptmore,
          Instserver.is_service_pack
        )

        if total_cds == current_cd && !standalone && !baseproduct && !promptmore
          Builtins.y2milestone("Restarting media counter...")

          # ask for the base product
          restart = true
          current_cd = 1
          media_id = ""
          total_cds = 1
          prompt_totalcds = 0
          medianames = []

          prompt_string = base
        elsif total_cds == current_cd && (standalone || baseproduct)
          break
        elsif total_cds == current_cd && promptmore
          break
        else
          current_cd = Ops.add(current_cd, 1)
          Builtins.y2milestone("next cd: %1", current_cd)
        end
        Instserver.standalone = standalone
      end
      return :abort if failed

      if content_first_CD != "" && !code10_source
        Builtins.y2milestone("writing content file from the 1st CD...")
        SCR.Execute(path(".target.remove"), Ops.add(dir, "/content"))
        SCR.Write(
          path(".target.string"),
          Ops.add(dir, "/content"),
          content_first_CD
        )
      end

      if !code10_source
        Builtins.y2milestone("creating new root directory.yast....")
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat(
            "/usr/bin/rm -f %1/directory.yast; cd %1; /usr/bin/ls -p | /usr/bin/grep -v -e '^\\.$' -e '^\\.\\.$' -e 'directory.yast' > %1/directory.yast",
            dir.shellescape
          )
        )

        Builtins.y2milestone("standalone_product: %1", standalone_product)

        # refresh MD5SUMS only when it's a standalone product and number of CDs > 1
        if standalone_product && Ops.greater_than(total_cds, 1)
          # recreate MD5SUM files
          out = Convert.to_map(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat("/usr/bin/find %1 -type f -name MD5SUMS", dir.shellescape)
            )
          )
          Builtins.foreach(
            Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
          ) do |file|
            if file != ""
              md5dir = Builtins.substring(
                file,
                0,
                Builtins.search(file, "/MD5SUMS")
              )
              # don't change MD5SUMS in product description directory,
              # SHA1 sum of the file is in _signed_ content file
              if md5dir == nil || md5dir == "" ||
                  Builtins.issubstring(file, "/setup/descr")
                next
              end

              SCR.Execute(path(".target.remove"), file)

              command = Builtins.sformat("cd %1; /usr/bin/md5sum * > MD5SUMS", md5dir.shellescape)
              Builtins.y2milestone("Command: %1", command)
              SCR.Execute(path(".target.bash"), command, { "LANG" => "C" })
            end
          end
        end
      end

      :next
    end

    def CDdevices
      cds = Convert.convert(
        SCR.Read(path(".probe.cdrom")),
        :from => "any",
        :to   => "list <map>"
      )
      ret = []

      Builtins.foreach(cds) do |cd|
        dev = Ops.get_string(cd, "dev_name", "")
        model = Ops.get_string(cd, "model", "")
        if dev != nil && dev != "" && model != nil
          ret = Builtins.add(
            ret,
            Item(Id(dev), Ops.add(model, Builtins.sformat(" (%1)", dev)))
          )
        end
      end if cds != nil

      deep_copy(ret)
    end

    # Repository configuration dialog
    # @return dialog result
    def MediaDialog
      # Instserver configuration dialog caption
      caption = _("Repository Configuration")

      isodir = Ops.get_string(Instserver.ServerSettings, "iso-dir", "")
      cddevs = CDdevices()
      iso = Builtins.size(cddevs) == 0

      # Instserver configure1 dialog contents
      contents = HVSquash(
        VBox(
          RadioButtonGroup(
            Id(:rbg),
            VBox(
              Left(
                RadioButton(
                  Id(:disk),
                  Opt(:notify),
                  _("Read &CD or DVD Medium"),
                  iso == false
                )
              ),
              HBox(
                HSpacing(3),
                ComboBox(Id(:drive), _("Data &Source"), cddevs),
                HStretch()
              ),
              VSpacing(1),
              Left(
                RadioButton(
                  Id(:iso),
                  Opt(:notify),
                  _("Use &ISO Images"),
                  iso == true
                )
              )
            )
          ),
          VSquash(
            HBox(
              HSpacing(3),
              TextEntry(Id(:isodir), _("Di&rectory with CD Images:"), isodir),
              VBox(
                VSpacing(),
                Bottom(PushButton(Id(:select_dir), _("Select &Directory")))
              )
            )
          )
        )
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "initial2", ""),
        Label.BackButton,
        Label.NextButton
      )

      UI.ChangeWidget(Id(:isodir), :Enabled, iso)
      UI.ChangeWidget(Id(:select_dir), :Enabled, iso)

      # disable CD widgets when there is no drive detected
      if Builtins.size(cddevs) == 0
        UI.ChangeWidget(Id(:disk), :Enabled, false)
        UI.ChangeWidget(Id(:drive), :Enabled, false)
      end

      ret = nil
      while true
        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == :disk || ret == :iso
          iso = Convert.to_boolean(UI.QueryWidget(Id(:iso), :Value))
          UI.ChangeWidget(Id(:isodir), :Enabled, iso)
          UI.ChangeWidget(Id(:select_dir), :Enabled, iso)
          UI.ChangeWidget(Id(:drive), :Enabled, !iso)
        elsif ret == :select_dir
          new_dir = UI.AskForExistingDirectory(isodir, _("Select Directory"))
          if new_dir != nil
            UI.ChangeWidget(Id(:isodir), :Value, Convert.to_string(new_dir))
          end
          next
        elsif ret == :next
          iso2 = Convert.to_boolean(UI.QueryWidget(Id(:iso), :Value))
          dir = Ops.get_string(Instserver.Config, "directory", "")
          target = Ops.add(
            Ops.add(
              Ops.get_string(Instserver.ServerSettings, "directory", ""),
              "/"
            ),
            dir
          )

          if dir == ""
            Popup.Error(_("Installation server name missing."))
            next
          end

          Ops.set(
            Instserver.ServerSettings,
            "iso-dir",
            Convert.to_string(UI.QueryWidget(Id(:isodir), :Value))
          )

          selecteddrive = Convert.to_string(UI.QueryWidget(Id(:drive), :Value))
          ret2 = :none

          if SCR.Read(path(".target.size"), Ops.add(target, "/content")) != -1
            Popup.Message(
              _("Contents already exist in this directory.\nNot copying CDs.")
            )
            ret2 = :next
          else
            ret2 = Convert.to_symbol(
              CopyCDs(target, :onedir, iso2, false, selecteddrive)
            )
          end

          if ret2 == :next
            # ask for an addon only when the product is pre-CODE10
            ask_for_addon = false

            if Ops.greater_than(
                SCR.Read(path(".target.size"), Ops.add(target, "/content")),
                0
              )
              content_file = ReadContentFile(Ops.add(target, "/content"))
              Builtins.y2debug("Parsed content file: %1", content_file)

              ask_for_addon = !code10(content_file)
            end

            Builtins.y2milestone("ask_for_addon: %1", ask_for_addon)

            # for translators: popup question (prefer more shorter lines than few long lines)
            while ask_for_addon &&
                Popup.YesNo(
                  _(
                    "Add an additional product (Service Pack, Additional\nPackage CD, etc.) to the repository?"
                  )
                ) == true
              CopyCDs(target, :onedir, iso2, true, selecteddrive)
            end
          end

          if ret2 == :next
            content = {}
            contentpath = Builtins.sformat("%1/content", target)

            Instserver.createOrderFiles(target)

            if Ops.greater_than(SCR.Read(path(".target.size"), contentpath), 0)
              content = ReadContentFile(contentpath)
            else
              Builtins.y2milestone("cannot read %1", contentpath)
              # try CD1 subdir if the previous attempt has failed
              contentpath = Builtins.sformat("%1/CD1/content", target)

              if Ops.greater_than(
                  SCR.Read(path(".target.size"), contentpath),
                  0
                )
                content = ReadContentFile(contentpath)
              else
                Builtins.y2error(
                  "cant read content file, something nasty happened: %1",
                  contentpath
                )
              end
            end

            Builtins.y2debug("content: %1", content)
            Instserver.Config = Convert.convert(
              Builtins.union(Instserver.Config, content),
              :from => "map",
              :to   => "map <string, any>"
            )
          else
            # copying has been aborted, remove the repository
            cmd = "/bin/rm -rf #{target.shellescape}"
            Builtins.y2milestone("Removing directory %1", target)

            if SCR.Execute(path(".target.bash"), cmd) != 0
              Builtins.y2error("Cannot remove directory %1", target)
            end

            Instserver.Config = {}
          end

          Instserver.UpdateConfig
          Instserver.modified = true
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      deep_copy(ret)
    end

    # Repository configuration dialog
    # @return dialog result
    def SourceConfigDialog
      # Instserver configuration dialog caption
      caption = _("Repository Configuration")

      dir = Ops.get_string(Instserver.Config, "directory", "")
      slp = Ops.get_boolean(Instserver.Config, "slp", false)

      # Instserver configure1 dialog contents
      contents = HVSquash(
        VBox(
          Left(TextEntry(Id(:dir), _("Repository &Name:"), dir)),
          VSpacing(1),
          Left(
            CheckBox(
              Id(:slp),
              _("A&nnounce as Installation Service with SLP"),
              slp
            )
          )
        )
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "initial", ""),
        Label.BackButton,
        Label.NextButton
      )

      current = deep_copy(Instserver.Config)

      ret = nil
      while true
        ret = UI.UserInput
        dir = Convert.to_string(UI.QueryWidget(Id(:dir), :Value))
        target = Ops.add(
          Ops.add(
            Ops.get_string(Instserver.ServerSettings, "directory", ""),
            "/"
          ),
          dir
        )

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == :next
          if dir == ""
            Popup.Error(_("Installation server name missing."))
            next
          elsif dir !=
              Builtins.filterchars(
                dir,
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-."
              ) ||
              Ops.greater_than(Builtins.size(dir), 127)
            errmsg = _("Invalid repository name.")
            Popup.Error(errmsg)
            next
          elsif dir != Ops.get_string(Instserver.Config, "name", "") &&
              Builtins.haskey(Instserver.Configs, dir)
            # an error message - entered repository name already exists
            Popup.Error(
              Builtins.sformat(
                _("Repository '%1' already exists,\nenter another name."),
                dir
              )
            )
            next
          # create directory only for a new repository
          elsif Instserver.Config == {}
            mkdircmd = "mkdir -p #{target.shellescape}"

            Builtins.y2debug("executing: %1", mkdircmd)
            if SCR.Execute(path(".target.bash"), mkdircmd) != 0
              Popup.Error(
                Builtins.sformat(
                  _(
                    "Error while creating <tt>repository</tt> directory.\n" +
                      "Verify that the directory \n" +
                      " %1 \n" +
                      "is writable and try again.\n"
                  ),
                  Ops.get_string(Instserver.ServerSettings, "directory", "")
                )
              )
              next
            end
          end

          # check if the repository has been already removed (bnc#187280)
          if Builtins.contains(Instserver.to_delete, dir)
            Builtins.y2milestone("Repository %1 has been marked to delete", dir)

            # confirm removal of a repository, the action is done immediately and cannot be reverted
            confirm = Builtins.sformat(
              _(
                "Repository '%1' has been marked to delete.\n" +
                  "When adding a new repository with the same name\n" +
                  "the old content must deleted right now.\n" +
                  "\n" +
                  "Really delete the old content and create it from scratch?"
              ),
              dir
            )

            if Popup.YesNo(confirm)
              Builtins.y2milestone("Removing the old repository")
              rmdir = Ops.add(
                Ops.add(
                  Ops.get_string(Instserver.ServerSettings, "directory", ""),
                  "/"
                ),
                dir
              )
              rm = Builtins.sformat("rm -rf '%1'", String.Quote(rmdir))

              Builtins.y2milestone("Executing: %1", rm)
              SCR.Execute(path(".target.bash"), rm)

              # remove it from to_delete list, it has just been deleted
              Instserver.to_delete = Builtins.filter(Instserver.to_delete) do |del|
                del != dir
              end

              Builtins.y2milestone(
                "Updated list of removed repositories: %1",
                Instserver.to_delete
              )
            else
              Builtins.y2milestone("Not removing the old repository")
              next
            end
          end


          if dir != Ops.get_string(Instserver.Config, "name", "") &&
              Ops.get_string(Instserver.Config, "name", "") != ""
            # mark the directory content for moving at write
            Instserver.renamed = Builtins.add(
              Instserver.renamed,
              Ops.get_string(Instserver.Config, "name", ""),
              dir
            )

            # remove the old configuration in Instserver::UpdateConfig()
            Ops.set(
              Instserver.Config,
              "old_name",
              Ops.get_string(Instserver.Config, "name", "")
            )
          end

          slp = Convert.to_boolean(UI.QueryWidget(Id(:slp), :Value))

          Ops.set(Instserver.Config, "name", dir)
          Ops.set(Instserver.Config, "directory", dir)
          Ops.set(Instserver.Config, "slp", slp)

          if current != {}
            # update modified repository now, the workflow has in this case only one step
            Instserver.UpdateConfig
            Instserver.modified = true
          end

          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      deep_copy(ret)
    end


    # Server dialog
    # @return dialog result
    def ServerDialog
      # Instserver server dialog caption
      caption = _("Initial Setup -- Initial Setup")

      dir = Ops.get_string(
        Instserver.ServerSettings,
        "directory",
        "/srv/install"
      )
      dry = Ops.get_boolean(Instserver.ServerSettings, "dry", false)
      source = Ops.get_symbol(Instserver.ServerSettings, "service", :http)

      c1 = HBox(
        VBox(
          Left(
            CheckBox(
              Id(:dry),
              Opt(:notify),
              _("Do Not Configure Any Net&work Services")
            )
          ),
          VSquash(
            HBox(
              TextEntry(Id(:dir), _("Di&rectory to Contain Repositories:"), dir),
              VBox(
                VSpacing(),
                Bottom(PushButton(Id(:select_dir), _("Select &Directory")))
              )
            )
          )
        )
      )

      buttons = VBox(
        # radio button label
        Left(
          RadioButton(
            Id(:http),
            _("&Configure as HTTP Repository"),
            source == :http
          )
        ),
        # radio button label
        Left(
          RadioButton(
            Id(:ftp),
            _("&Configure as FTP Repository"),
            source == :ftp
          )
        ),
        # radio button label
        Left(
          RadioButton(
            Id(:nfs),
            _("&Configure as NFS Repository"),
            source == :nfs
          )
        )
      )

      # Instserver configure2 dialog contents
      contents = HVSquash(
        VBox(RadioButtonGroup(Id(:service), buttons), VSpacing(1), c1)
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "server", "server"),
        Label.BackButton,
        Label.NextButton
      )

      ret = nil
      while true
        dry = Convert.to_boolean(UI.QueryWidget(Id(:dry), :Value))
        if dry
          UI.ChangeWidget(Id(:service), :Enabled, false)
        else
          UI.ChangeWidget(Id(:service), :Enabled, true)
        end

        ret = UI.UserInput

        source = Convert.to_symbol(UI.QueryWidget(Id(:service), :CurrentButton))
        dir = Convert.to_string(UI.QueryWidget(Id(:dir), :Value))

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        elsif ret == :select_dir
          new_dir = UI.AskForExistingDirectory(dir, _("Select Directory"))
          if new_dir != nil
            UI.ChangeWidget(Id(:dir), :Value, Convert.to_string(new_dir))
          end
          next
        elsif ret == :back
          break
        elsif ret == :next
          r = false
          if dir == ""
            Popup.Error(
              _("Directory path for the installation server missing.")
            )
            next
          end
          Ops.set(Instserver.ServerSettings, "service", source)
          Ops.set(Instserver.ServerSettings, "dry", dry)
          Ops.set(Instserver.ServerSettings, "directory", dir)
          Instserver.modified = true
          if dry
            ret = :next
          else
            ret = source
          end
          break
        elsif ret != :dry
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      deep_copy(ret)
    end

    # NFS dialog
    # @return dialog result
    def NfsDialog
      # Instserver configure2 dialog caption
      caption = _("Installation Server -- NFS")

      nfsoptions = "ro,root_squash,sync,no_subtree_check"
      wildcard = "*"

      # firewall widget using CWM
      fw_settings = {
        "services"        => ["nfs-kernel-server"],
        "display_details" => true
      }

      fw_cwm_widget = CWMFirewallInterfaces.CreateOpenFirewallWidget(
        fw_settings
      )

      # Instserver nfs dialog contents
      contents = HVSquash(
        VBox(
          Left(TextEntry(Id(:wildcard), _("&Host Wild Card"), wildcard)),
          VSpacing(0.5),
          Left(TextEntry(Id(:nfsoptions), _("&Options"), nfsoptions)),
          VSpacing(1),
          Ops.get_term(fw_cwm_widget, "custom_widget", Empty())
        )
      )


      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.add(
          Ops.get_string(@HELPS, "nfs", "nfs"),
          Ops.get_string(fw_cwm_widget, "help", "")
        ),
        Label.BackButton,
        Label.NextButton
      )

      # initialize the firewall widget (set the current value)
      CWMFirewallInterfaces.OpenFirewallInit(fw_cwm_widget, "")

      ret = nil
      event = {}

      while true
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == :next
          r = false
          nfsoptions = Convert.to_string(
            UI.QueryWidget(Id(:nfsoptions), :Value)
          )
          wildcard = Convert.to_string(UI.QueryWidget(Id(:wildcard), :Value))
          if !Ops.get_boolean(Instserver.ServerSettings, "dry", false)
            # store the firewall setting, (activation is in SetupNFS())
            CWMFirewallInterfaces.OpenFirewallStore(fw_cwm_widget, "", event)

            r = Instserver.SetupNFS(
              Ops.get_string(Instserver.ServerSettings, "directory", ""),
              Ops.add(
                Ops.add(
                  Ops.add(wildcard, "("),
                  Builtins.deletechars(nfsoptions, " ")
                ),
                ")"
              )
            )
            if !r
              Popup.Error(_("Error occurred while configuring NFS."))
              next
            end
          end
          Instserver.modified = true


          break
        end

        # handle the events, enable/disable the button, show the popup if button clicked
        CWMFirewallInterfaces.OpenFirewallHandle(fw_cwm_widget, "", event)
      end

      deep_copy(ret)
    end


    # Ftp dialog
    # @return dialog result
    def FtpDialog
      # firewall widget using CWM
      fw_settings = {
        "services"        => ["vsftpd"],
        "display_details" => true
      }

      fw_cwm_widget = CWMFirewallInterfaces.CreateOpenFirewallWidget(
        fw_settings
      )

      # Instserver configure2 dialog caption
      caption = _("Installation Server -- FTP")

      ftproot = Ops.get_string(Instserver.ServerSettings, "ftproot", "/srv/ftp")
      ftpalias = Ops.get_string(Instserver.ServerSettings, "ftpalias", "")
      # Instserver nfs dialog contents
      contents = HVSquash(
        VBox(
          Left(
            TextEntry(Id(:ftproot), _("&FTP Server Root Directory:"), ftproot)
          ),
          Left(TextEntry(Id(:ftpalias), _("&Directory Alias:"), ftpalias)),
          VSpacing(1),
          Ops.get_term(fw_cwm_widget, "custom_widget", Empty())
        )
      )


      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "ftp", "ftp"),
        Label.BackButton,
        Label.NextButton
      )

      # install packages before calling SuSEFirewall::Read()
      # to read the service definition file
      if !Instserver.InstallFTPPackages
        Builtins.y2error("FTP server package is not installed, cannot continue")
        return :abort
      end

      # initialize the firewall widget (set the current value)
      CWMFirewallInterfaces.OpenFirewallInit(fw_cwm_widget, "")

      ret = nil
      event = {}

      while true
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")

        ftproot = Convert.to_string(UI.QueryWidget(Id(:ftproot), :Value))
        ftpalias = Convert.to_string(UI.QueryWidget(Id(:ftpalias), :Value))

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == :next
          r = false
          Ops.set(Instserver.ServerSettings, "ftproot", ftproot)
          Ops.set(Instserver.ServerSettings, "ftpalias", ftpalias)
          if !Ops.get_boolean(Instserver.ServerSettings, "dry", false)
            # store the firewall setting, (activation is in SetupFTP())
            CWMFirewallInterfaces.OpenFirewallStore(fw_cwm_widget, "", event)
            r = Instserver.SetupFTP(
              Ops.get_string(Instserver.ServerSettings, "directory", ""),
              ftproot,
              ftpalias
            )
            if !r
              Popup.Error(_("Error occurred while configuring FTP."))
              ret = :back
              break
            end
          end
          Instserver.modified = true
          break
        end

        # handle the events, enable/disable the button, show the popup if the firewall button has been clicked
        CWMFirewallInterfaces.OpenFirewallHandle(fw_cwm_widget, "", event)
      end

      deep_copy(ret)
    end

    # Http dialog
    # @return dialog result
    def HttpDialog
      # Instserver configure2 dialog caption
      caption = _("Installation Server -- HTTP")

      # firewall widget using CWM
      fw_settings = {
        "services"        => ["apache2"],
        "display_details" => true
      }

      fw_cwm_widget = CWMFirewallInterfaces.CreateOpenFirewallWidget(
        fw_settings
      )

      _alias = Ops.get_string(Instserver.ServerSettings, "alias", "")
      # Instserver nfs dialog contents
      contents = HVSquash(
        VBox(
          Left(TextEntry(Id(:alias), _("&Directory Alias"), _alias)),
          VSpacing(1),
          Ops.get_term(fw_cwm_widget, "custom_widget", Empty())
        )
      )


      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.add(
          Ops.get_string(@HELPS, "http", "http"),
          Ops.get_string(fw_cwm_widget, "help", "")
        ),
        Label.BackButton,
        Label.NextButton
      )

      # initialize the firewall widget (set the current value)
      CWMFirewallInterfaces.OpenFirewallInit(fw_cwm_widget, "")

      ret = nil
      event = {}

      # install packages before calling SuSEFirewall::Read()
      # to read the service definition file
      if !Instserver.InstallHTTPPackages
        Builtins.y2error(
          "HTTP server package is not installed, cannot continue"
        )
        return :abort
      end

      while true
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == :next
          _alias = Convert.to_string(UI.QueryWidget(Id(:alias), :Value))
          Ops.set(Instserver.ServerSettings, "alias", _alias)
          if !Ops.get_boolean(Instserver.ServerSettings, "dry", false)
            # store the firewall setting, (activation is in SetupHTTP())
            CWMFirewallInterfaces.OpenFirewallStore(fw_cwm_widget, "", event)

            if !Instserver.SetupHTTP(
                Ops.get_string(Instserver.ServerSettings, "directory", ""),
                _alias
              )
              Popup.Error(_("Error creating HTTPD configuration."))
              ret = :back
              break
            end
          end
          Instserver.modified = true
          break
        end

        # handle the events, enable/disable the button, show the popup if button clicked
        CWMFirewallInterfaces.OpenFirewallHandle(fw_cwm_widget, "", event)
      end

      deep_copy(ret)
    end
  end
end
