# encoding: utf-8

# File:	modules/Instserver.rb
# Package:	Configuration of Installation Server
# Summary:	Installation Server settings, input and output functions
# Authors:	Anas Nashif <nashif@suse.de>
#
# Representation of the configuration of Installation Server.
# Input and output routines.
require "yast"
require "y2firewall/firewalld"
require "yast2/systemd/socket"
require "shellwords"

module Yast
  class InstserverClass < Module
    NFS_SERVER_SEVICE = "nfs-server".freeze

    def main
      textdomain "instserver"

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"
      Yast.import "XML"
      Yast.import "Popup"
      Yast.import "Package"
      Yast.import "Call"
      Yast.import "Service"
      Yast.import "IP"
      Yast.import "Message"
      Yast.import "String"

      Yast.include self, "instserver/routines.rb"


      # Is this a service pack?
      @is_service_pack = false

      @test = false

      # Configuration Map
      @Config = {}

      # All Configurations
      @Configs = {}

      # Server Configuration
      @ServerSettings = {}

      # Configuration Repository
      @Rep = "/etc/YaST2/instserver"

      # config file
      @ConfigFile = Ops.add(@Rep, "/instserver.xml")


      @FirstDialog = "summary"


      @products = []


      @Detected = []

      @standalone = false

      # renamed repositories: $["old" : "new"]
      @renamed = {}

      # Data was modified?
      @modified = false



      @to_delete = []

      # Abort function
      # return boolean return true if abort
      @AbortFunction = Modified()
      Instserver()
    end

    def firewalld
      Y2Firewall::Firewalld.instance
    end

    # Abort function
    # @return [Boolean]
    def Abort
      return Builtins.eval(@AbortFunction) if @AbortFunction != nil
      false
    end

    # Data was modified?
    # @return true if modified
    def Modified
      Builtins.y2debug("modified=%1", @modified)
      @modified
    end


    def vsftpd_is_standalone
      ret = SCR.Execute(
        path(".target.bash"),
        "/usr/bin/grep -q '^listen=YES$' /etc/vsftpd.conf"
      ) == 0

      Builtins.y2milestone("vsftpd in standalone mode: %1", ret)
      ret
    end

    # Create links
    def createLinks(dir, product, files)
      files = deep_copy(files)
      shorttgt = Builtins.sformat("%1/CD%2", product, 1)
      cmds = []

      Builtins.foreach(files) do |symlink|
        f = Builtins.sformat("%1/%2/%3", dir, shorttgt, symlink)
        # always return success - the link may be missing if the target file doesn't exist
        cmds = Builtins.add(
          cmds,
          Builtins.sformat(
            "( test -f %1 || test -d %2) &&  pushd %3 && ln -sf %4/%5 && popd; exit 0",
            f,
            f,
            dir,
            shorttgt,
            symlink
          )
        )
      end
      cmds = Builtins.add(cmds, Builtins.sformat("mkdir -p %1/yast", dir))

      Builtins.y2debug("cmds: %1", cmds)
      deep_copy(cmds)
    end


    # Create yast directory with ordr/instorder files
    # @param string directory
    # @return booelan
    def createOrderFiles(dir)
      if Ops.greater_than(Builtins.size(@products), 1)
        SCR.Execute(path(".target.mkdir"), Ops.add(dir, "/yast"))

        Builtins.y2milestone("products: %1", @products)
        # create order: Service Packs, products which require any other product, other products
        order = Builtins.filter(@products) do |p|
          Ops.get_boolean(p, "SP", false)
        end
        order = Convert.convert(
          Builtins.union(order, Builtins.filter(@products) do |p|
            !Ops.get_boolean(p, "baseproduct", false) &&
              !Ops.get_boolean(p, "SP", false)
          end),
          :from => "list",
          :to   => "list <map>"
        )
        order = Convert.convert(
          Builtins.union(order, Builtins.filter(@products) do |p|
            Ops.get_boolean(p, "baseproduct", false) &&
              !Ops.get_boolean(p, "SP", false)
          end),
          :from => "list",
          :to   => "list <map>"
        )
        Builtins.y2milestone("order: %1", order)

        instorder = Builtins.filter(@products) do |p|
          Ops.get_boolean(p, "baseproduct", false)
        end
        instorder = Convert.convert(
          Builtins.union(instorder, Builtins.filter(@products) do |p|
            !Ops.get_boolean(p, "baseproduct", false)
          end),
          :from => "list",
          :to   => "list <map>"
        )

        # HACK: support sles8 too
        ul = Builtins.filter(instorder) do |u|
          Builtins.issubstring(
            Builtins.tolower(Ops.get_string(u, "name", "")),
            "unitedlinux"
          )
        end
        instorder = deep_copy(order) if Builtins.size(ul) == 0
        Builtins.y2milestone("instorder: %1", instorder)

        file = []
        Builtins.foreach(order) do |p|
          # workaround for NLD9 - if the subdir doesn't exists use root
          proddir = Ops.less_than(
            SCR.Read(
              path(".target.size"),
              Ops.add(Ops.add(dir, "/"), Ops.get_string(p, "name", ""))
            ),
            0
          ) ?
            "/" :
            Builtins.sformat("/%1/CD1", Ops.get_string(p, "name", ""))
          file = Builtins.add(
            file,
            Builtins.mergestring([proddir, proddir], "\t")
          )
        end
        file = Builtins.add(file, "")
        SCR.Write(
          path(".target.string"),
          Ops.add(dir, "/yast/order"),
          Builtins.mergestring(file, "\n")
        )
        file = []
        Builtins.foreach(instorder) do |p|
          # workaround for NLD9 - if the subdir doesn't exists use root
          proddir = Ops.less_than(
            SCR.Read(
              path(".target.size"),
              Ops.add(Ops.add(dir, "/"), Ops.get_string(p, "name", ""))
            ),
            0
          ) ?
            "/" :
            Builtins.sformat("/%1/CD1", Ops.get_string(p, "name", ""))
          file = Builtins.add(file, proddir)
        end
        file = Builtins.add(file, "")
        SCR.Write(
          path(".target.string"),
          Ops.add(dir, "/yast/instorder"),
          Builtins.mergestring(file, "\n")
        )
      end
      @products = []

      true
    end


    # Mount directory to avoid symlinks
    # @param string directory to bind
    # @param string bind to
    # @return [Boolean] (true means that /etc/fstab has been modified)
    def MountBind(dir, ftproot)
      Builtins.y2milestone("Calling MountBind with: %1 %2", dir, ftproot)
      fstab = Convert.convert(
        SCR.Read(path(".etc.fstab")),
        :from => "any",
        :to   => "list <map>"
      )
      Builtins.y2debug("fstab: %1", fstab)
      exists = Builtins.filter(fstab) do |f|
        Ops.get_string(f, "spec", "") == Builtins.deletechars(dir, " ")
      end
      Builtins.y2milestone("existing: %1", exists)
      if Ops.greater_than(Builtins.size(exists), 0)
        return false
      else
        SCR.Execute(path(".target.mkdir"), ftproot)
        Builtins.y2milestone("mounting %1 to %2", dir, ftproot)
        SCR.Execute(path(".target.mount"), [dir, ftproot], "--bind")

        bindfs = {}
        bindfs = {
          "file"    => ftproot,
          "spec"    => dir,
          "freq"    => 1,
          "mntops"  => "bind",
          "passno"  => 1,
          "vfstype" => "auto"
        }

        fstab = Builtins.add(fstab, bindfs)

        Builtins.y2milestone("added /etc/fstab entry: %1", bindfs)
        SCR.Write(path(".etc.fstab"), fstab)
      end
      true
    end


    # Configure service using _auto
    def ConfigureService(module_auto, resource)
      resource = deep_copy(resource)
      Builtins.y2milestone(
        "New configuration for service %1: %2",
        module_auto,
        resource
      )

      ret = false
      ret = Convert.to_boolean(Call.Function(module_auto, ["Import", resource]))
      ret = Convert.to_boolean(Call.Function(module_auto, ["Write", resource]))
      ret
    end

    # Read service data using _auto
    def ReadServiceSettings(module_auto)
      r = Convert.to_boolean(Call.Function(module_auto, ["Read"]))
      ret = Call.Function(module_auto, ["Export"])

      Builtins.y2milestone(
        "Current configuration of service %1: %2",
        module_auto,
        ret
      )

      deep_copy(ret)
    end

    def InstallFTPPackages
      help = _(
        "The FTP installation server requires an FTP server package. The vsftpd package\nwill now be installed.\n"
      )
      if !Package.InstalledAll(
          ["vsftpd", "openslp-server"]
        )
        Builtins.y2milestone("some packages are not installed")
      else
        return true
      end

      if !Package.InstallAll(
          ["vsftpd", "openslp-server"]
        )
        Report.Error(Message.CannotContinueWithoutPackagesInstalled)
        Builtins.y2error("Error while installing packages")
        return false
      end

      true
    end

    # Setup FTP server
    # @param string inst server root
    # @param string ftp server root
    # @return [Boolean]
    def SetupFTP(dir, ftproot, ftpalias)
      return false if !InstallFTPPackages()

      # create repository directory if it doesn't exist
      SCR.Execute(
        path(".target.bash"),
        "/usr/bin/mkdir -p #{dir.shellescape}"
      )

      if !Builtins.issubstring(dir, ftproot)
        if ftpalias != ""
          a = ""
          a = Ops.add(Ops.add(ftproot, "/"), ftpalias)
          SCR.Execute(path(".target.bash"), "/usr/bin/mkdir -p #{a.shellescape}")
          ftproot = a
        end
        Builtins.y2milestone("binding dir")
        MountBind(dir, ftproot)
      else
        # FIXME
        Builtins.y2warning("not implemented")
      end

      # check if vsftpd is configured in standalone mode (listen=YES) (bnc#438694)
      # see 'man vsftpd.conf'
      vsftpd_standalone = vsftpd_is_standalone

      if vsftpd_standalone
        Builtins.y2milestone("Configuring FTP service in standalone mode")

        # enable/start the service
        Service.Enable("vsftpd")
        if Service.Status("vsftpd") == 0
          Service.Reload("vsftpd")
        else
          Service.Start("vsftpd")
        end
      elsif socket
        Builtins.y2milestone("Enabling vsftpd socket")
        socket.enable unless socket.enabled?
        socket.start unless socket.listening?
      end

      firewalld.write

      true
    end

    # Write Apache config
    # @param string state : Yes/No
    # @return [void]
    def RunSuseConfigApache(enable)
      flags = Convert.to_string(
        SCR.Read(path(".sysconfig.apache2.APACHE_SERVER_FLAGS"))
      )
      if !Builtins.issubstring(flags, "inst_server") && enable
        SCR.Write(
          path(".sysconfig.apache2.APACHE_SERVER_FLAGS"),
          Ops.add(flags, " inst_server")
        )
      elsif Builtins.issubstring(flags, "inst_server") && !enable
        SCR.Write(
          path(".sysconfig.apache2.APACHE_SERVER_FLAGS"),
          Builtins.regexpsub(flags, "(.*)inst_server(.*)", "")
        )
      end

      if !SCR.Write(path(".sysconfig.apache2"), nil)
        Popup.Error(_("Unable to write /etc/sysconfig/apache2"))
        return
      end

      nil
    end

    def InstallHTTPPackages
      help = _(
        "The HTTP installation server requires an HTTP server package. The apache2 package\nwill now be installed."
      )
      if !Package.InstalledAll(["apache2", "openslp-server"])
        Builtins.y2debug("some packages are not installed")

        if !Package.InstallAll(["apache2", "apache2-prefork", "openslp-server"])
          Report.Error(Message.CannotContinueWithoutPackagesInstalled)

          Builtins.y2error("Error while installing packages")
          return false
        end
      end

      true
    end

    # Setup HTTP server
    # @param string inst server root
    # @param [String] alias
    # @return [Boolean]
    def SetupHTTP(dir, _alias)
      return false if !InstallHTTPPackages()

      if Ops.greater_than(
          Convert.to_integer(
            SCR.Read(
              path(".target.size"),
              "/etc/apache2/conf.d/inst_server.conf.in"
            )
          ),
          0
        )
        conf = Convert.to_string(
          SCR.Read(
            path(".target.string"),
            "/etc/apache2/conf.d/inst_server.conf.in"
          )
        )
        confline = Builtins.splitstring(conf, "\n")

        _alias = Ops.add("/", _alias) if Builtins.findfirstof(_alias, "/") != 0
        confline = Builtins.maplist(confline) do |line|
          res = Builtins.regexpsub(
            line,
            "(.*)@ALIAS@(.*)",
            Builtins.sformat("\\1%1/\\2", _alias)
          )
          res = Builtins.regexpsub(
            res != nil ? Convert.to_string(res) : line,
            "(.*)@SERVERDIR@(.*)",
            Builtins.sformat("\\1%1/\\2", dir)
          )
          if res != nil
            next Convert.to_string(res)
          else
            next line
          end
        end

        Builtins.y2debug("conf: %1", confline)

        conf = Builtins.mergestring(confline, "\n")
        if !SCR.Write(
            path(".target.string"),
            "/etc/apache2/conf.d/inst_server.conf",
            conf
          )
          Builtins.y2error("Error writing apache2 config file")
        end
      else
        Builtins.y2error(
          "/etc/apache2/conf.d/inst_server.conf.in does not exist"
        )
        return false
      end
      RunSuseConfigApache(true)

      firewalld.write

      Service.Enable("apache2")
      if Service.Status("apache2") == 0
        Service.Reload("apache2")
      else
        Service.Start("apache2")
      end
      true
    end


    # Setup NFS Server
    # @param string directory
    # @param [String] options
    # @return [Boolean]
    def SetupNFS(dir, options)
      if !Package.InstallAll(["yast2-nfs-server"])
        Report.Error(Message.CannotContinueWithoutPackagesInstalled)

        Builtins.y2error("Error while installing packages")
        return false
      end

      resource = Convert.to_map(ReadServiceSettings("nfs_server_auto"))
      oldexp = Ops.get_list(resource, "nfs_exports", [])
      Builtins.y2milestone("oldexp: %1", oldexp)

      oldexists = Builtins.filter(oldexp) do |e|
        Ops.get_string(e, "mountpoint", "") == dir
      end
      if Ops.greater_than(Builtins.size(oldexists), 0)
        yesno = Popup.YesNo(
          _(
            "Directory is already exported via NFS.\nLeave NFS exports unmodified?\n"
          )
        )
        if yesno
          return true
        else
          oldexp = Builtins.filter(oldexp) do |e|
            Ops.get_string(e, "mountpoint", "") != dir
          end
        end
      end
      exports = deep_copy(oldexp)
      nfs = {}
      Ops.set(nfs, "start_nfsserver", true)
      allowed = []
      if Builtins.size(options) == 0
        options = "*(ro,root_squash,sync,no_subtree_check)"
      end
      allowed = Builtins.add(allowed, options)
      ex = {}
      Ops.set(ex, "allowed", allowed)
      Ops.set(ex, "mountpoint", dir)
      exports = Builtins.add(exports, ex)
      Ops.set(nfs, "nfs_exports", exports)

      ConfigureService("nfs_server_auto", nfs)

      Service.Enable(NFS_SERVER_SERVICE)
      if Service.Status(NFS_SERVER_SERVICE) == 0
        Service.Reload(NFS_SERVER_SERVICE)
      else
        Service.Start(NFS_SERVER_SERVICE)
      end

      firewalld.write

      true
    end

    # some values are not allowed in SLP attributes
    # and must be escaped ('\' followed by two hex numbers)
    # see RFC2614 (http://www.openslp.org/doc/rfc/rfc2614.txt)
    def EscapeSLPData(a)
      a = deep_copy(a)
      ret = {}

      Builtins.foreach(a) do |key, value|
        # String::Replace() enters endless loop in '\' -> '\5c' conversion
        # use splitstring() and mergestring() builtins instead
        new_key = Builtins.mergestring(Builtins.splitstring(key, "\\"), "\\5c")
        new_key = String.Replace(new_key, ".", "\\2e")
        new_key = String.Replace(new_key, "=", "\\3d")
        new_key = String.Replace(new_key, "#", "\\23")
        new_key = String.Replace(new_key, ";", "\\3b")

        new_value = Builtins.mergestring(
          Builtins.splitstring(value, "\\"),
          "\\5c"
        )
        new_value = String.Replace(new_value, "(", "\\28")
        new_value = String.Replace(new_value, ")", "\\29")
        new_value = String.Replace(new_value, ",", "\\2c")
        new_value = String.Replace(new_value, "#", "\\23")
        new_value = String.Replace(new_value, ";", "\\3b")
        new_value = String.Replace(new_value, "!", "\\21")
        new_value = String.Replace(new_value, "<", "\\3c")
        new_value = String.Replace(new_value, "=", "\\3d")
        new_value = String.Replace(new_value, ">", "\\3e")
        new_value = String.Replace(new_value, "~", "\\7e")
        Ops.set(ret, new_key, new_value)
      end


      Builtins.y2milestone("Escaped SLP attributes: %1 -> %2", a, ret)

      deep_copy(ret)
    end

    def subreplace(text, _in, out)
      parts = Builtins.splitstring(text, "\\")

      # don't modify the first item, it's the non-matched prefix
      first = true
      new_parts = Builtins.maplist(parts) do |p|
        if first
          first = false
          next p
        end
        new_part = p
        if _in == Builtins.substring(p, 0, 2)
          new_part = Ops.add(out, Builtins.substring(p, 2))
        else
          # put the backslash back if the remaining part doesn't match
          new_part = Ops.add("\\", p)
        end
        new_part
      end

      ret = Builtins.mergestring(new_parts, "")
      Builtins.y2debug(
        "unescaped str: text: %1, in: %2, out: %3 => %4",
        text,
        _in,
        out,
        ret
      )

      ret
    end

    # this is an oppsite function to EscapeSLPData()
    # it takes SLP input and unescpaes the backslash sequences
    def UnEscapeSLPData(a)
      a = deep_copy(a)
      ret = {}

      Builtins.foreach(a) do |key, value|
        # String::Replace() enters endless loop in '\' -> '\5c' conversion
        # use splitstring() and mergestring() builtins instead
        new_key = key
        new_key = subreplace(new_key, "2e", ".")
        new_key = subreplace(new_key, "3d", "=")
        new_key = subreplace(new_key, "23", "#")
        new_key = subreplace(new_key, "3b", ";")
        new_key = subreplace(new_key, "5c", "\\")
        new_value = value
        new_value = subreplace(new_value, "28", "(")
        new_value = subreplace(new_value, "29", ")")
        new_value = subreplace(new_value, "2c", ",")
        new_value = subreplace(new_value, "23", "#")
        new_value = subreplace(new_value, "3b", ";")
        new_value = subreplace(new_value, "5c", "\\")
        Ops.set(ret, new_key, new_value)
      end


      Builtins.y2milestone("Unescaped SLP attributes: %1 -> %2", a, ret)

      deep_copy(ret)
    end

    # Return the IP address of the local machine
    # @return string IP Address
    def GetIPAddr
      ifconfig = Convert.convert(
        SCR.Read(path(".run.ifconfig")),
        :from => "any",
        :to   => "list <map>"
      )
      ifc = Builtins.filter(ifconfig) do |iface|
        Ops.get_string(iface, "name", "") == "eth0"
      end
      ip = Ops.get_integer(ifc, [0, "value", "inet", "addr"], 0)
      if ip == 0
        ifc = Builtins.filter(ifconfig) do |iface|
          Ops.get_string(iface, "name", "") != "lo" &&
            !Builtins.issubstring(Ops.get_string(iface, "name", ""), "dummy") &&
            Ops.get_integer(iface, ["value", "inet", "addr"], 0) != 0
        end
        ip = Ops.get_integer(ifc, [0, "value", "inet", "addr"], 0) if ifc != nil
      end

      IP.ToString(ip)
    end

    def GetHostname
      output = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "/usr/bin/hostname --long")
      )
      Builtins.y2milestone("hostname --long: %1", output)
      hostname = Ops.get_string(output, "stdout", "")

      hostname = Ops.get(Builtins.splitstring(hostname, "\n"), 0, "")

      hostname
    end

    def basearch_mapping(basearch)
      mapping = {
        "i586"   => ["i586", "i686"],
        "mips"   => ["mips", "mips64"],
        "ppc"    => ["ppc", "ppc64"],
        "sparc"  => ["sparc", "sparc64"],
        "x86_64" => ["x86_64"]
      }

      if !Builtins.haskey(mapping, basearch)
        Builtins.y2warning("Unknown BASEARCH: %1", basearch)
      end

      # return the original basearch if mapping is unknown
      ret = Ops.get(mapping, basearch) { [basearch] }

      Builtins.y2milestone("Using BASEARCH mapping: %1 -> %2", basearch, ret)

      deep_copy(ret)
    end

    def get_machines(basearch_value)
      archs = Builtins.splitstring(basearch_value, " ")
      archs = Builtins.filter(archs) { |a| a != nil && a != "" }

      ret = []

      Builtins.foreach(archs) do |a|
        ret = Convert.convert(
          Builtins.merge(ret, basearch_mapping(a)),
          :from => "list",
          :to   => "list <string>"
        )
      end


      Builtins.y2milestone("Final BASEARCH mapping: %1", ret)

      deep_copy(ret)
    end


    # Register service with SLP using a reg file
    # @param [String] service The service to be registered
    # @param [Hash{String => String}] attr Attributes
    # @param [String] regfile Reg File
    # @return [Boolean] True on Success
    def SLPRegFile(service, attr, regfile)

      slp = [service] + attr.map { |k, v| k.downcase + "=" + v }

      regd_path = "/etc/slp.reg.d"
      SCR.Execute(path(".target.mkdir"), regd_path)
      SCR.Write(path(".target.string"), "#{regd_path}/#{regfile}", slp.join("\n"))
    end

    # Write SLP configuration
    def WriteSLPReg(cm)
      cm = deep_copy(cm)
      Builtins.y2debug("WriteSLPReg(%1)", cm)

      ip = GetIPAddr()
      hostname = GetHostname()
      serv = ""
      regfile = Builtins.sformat("YaST-%1.reg", Ops.get_string(cm, "name", ""))
      if Ops.get_symbol(@ServerSettings, "service", :none) == :nfs
        serv = Builtins.sformat(
          "service:install.suse:nfs://%1/%2/%3%4,en,65535",
          ip,
          Ops.get_string(@ServerSettings, "directory", ""),
          Ops.get_string(cm, "name", ""),
          "/CD1"
        )
      elsif Ops.get_symbol(@ServerSettings, "service", :none) == :ftp
        serv = Builtins.sformat(
          "service:install.suse:ftp://%1/%2%3,en,65535",
          ip,
          Ops.get_string(cm, "name", ""),
          "/CD1"
        )
      elsif Ops.get_symbol(@ServerSettings, "service", :none) == :http
        serv = Builtins.sformat(
          "service:install.suse:http://%1/%2/%3%4,en,65535",
          ip,
          Ops.get_string(@ServerSettings, "alias", ""),
          Ops.get_string(cm, "name", ""),
          "/CD1"
        )
      end

      attr = {}
      Builtins.foreach(
        [
          "CPEID",
          "LABEL",
          "VERSION",
          "VENDOR",
          "DEFAULTBASE",
          "BASEPRODUCT",
          "BASEVERSION"
        ]
      ) do |a|
        if Ops.get_string(cm, a, "") != ""
          Ops.set(attr, Builtins.tolower(a), Ops.get_string(cm, a, ""))
        end
      end

      # Check if the description is already used
      # don't check file which will be rewritten
      #    string checkfiles = "/etc/slp.reg.d/YaST-*.reg";
      targetfile = Ops.add("/etc/slp.reg.d/", regfile)

      hostname_reg = ""
      # add the hostname
      if hostname != nil && hostname != "" && Builtins.haskey(attr, "label")
        hostname_reg = Ops.add(hostname, ": ")
      end

      descr = Ops.add(hostname_reg, Ops.get_string(cm, "LABEL", ""))
      if Ops.get_string(cm, "DISTPRODUCT", "") != ""
        descr = Ops.add(
          descr,
          Builtins.sformat(" [%2]", Ops.get_string(cm, "DISTPRODUCT", ""))
        )
      end

      Ops.set(attr, "description", descr)

      read_file = targetfile

      Builtins.foreach(@renamed) do |orig, new|
        if new == Ops.get_string(cm, "name", "")
          Builtins.y2milestone("Config renamed from %1 to %2", orig, new)

          read_file = Ops.add(
            "/etc/slp.reg.d/",
            Builtins.sformat("YaST-%1.reg", orig)
          )
        end
      end

      machines = []
      Builtins.foreach(cm) do |k, v|
        Builtins.y2debug("Read Key: '%1'", k)
        if k == "BASEARCHS"
          # machine mapping
          machines = get_machines(Convert.to_string(v))
        elsif Builtins.issubstring(k, "ARCH")
          a = Builtins.regexpsub(k, "ARCH\\.(.*)", "\\1")

          if a != nil
            Builtins.y2milestone(
              "Found %1 key, adding arch %2 to the list",
              k,
              a
            )
            machines = Builtins.add(machines, a)
          end
        end
      end
      machines = Builtins.filter(machines) { |m| m != "" && m != "noarch" }
      machines = Builtins.toset(machines)

      # sort the list so it looks better
      machines = Builtins.sort(machines)
      machines_string = Builtins.mergestring(machines, ",")

      Builtins.y2debug("machines: %1", machines)

      # preserve the old configuration
      if Ops.greater_or_equal(SCR.Read(path(".target.size"), read_file), 0)
        Builtins.y2milestone("Existing reg.d file found: %1", read_file)
        old_attr = {}

        reg_cont = Convert.to_string(
          SCR.Read(path(".target.string"), read_file)
        )
        lines = Builtins.splitstring(reg_cont, "\n")

        Builtins.foreach(lines) do |l|
          parsed_name = Builtins.regexpsub(
            l,
            "^[ \t]*([^ \t]*)[ \t]*=(.*)",
            "\\1"
          )
          parsed_value = Builtins.regexpsub(
            l,
            "^[ \t]*([^ \t]*)[ \t]*=(.*)",
            "\\2"
          )
          if parsed_name != nil
            Builtins.y2milestone(
              "Reusing attribute: %1=%2",
              parsed_name,
              parsed_value
            )
            Ops.set(old_attr, parsed_name, parsed_value)
          end
        end


        # unescape the read value
        old_attr = UnEscapeSLPData(old_attr)

        if Builtins.haskey(old_attr, "machine")
          # backup the "machine" value
          machines_string = Ops.get(old_attr, "machine", "")
        end

        # merge them with read values,
        # keep the original setting if a value was already set
        attr = Convert.convert(
          Builtins.union(attr, old_attr),
          :from => "map",
          :to   => "map <string, string>"
        )
      end

      # escape invalid characters
      attr = EscapeSLPData(attr)

      # replace the machine option after escaping,
      # it actually _is_ a list so "," is valid here
      attr["machine"] = machines_string unless machines_string.empty?
      Builtins.y2milestone("machine: %1", Ops.get(attr, "machine", ""))

      Builtins.y2milestone(
        "registering SLP service: serv: %1, attr: %2, regfile: %3",
        serv,
        attr,
        regfile
      )

      ret = SLPRegFile(serv, attr, regfile)

      ret
    end



    def DetectMedia
      if Ops.get_string(@ServerSettings, "directory", "") != ""
        f = Builtins.sformat(
          "/usr/bin/find %1 -maxdepth 2 -name content | /usr/bin/grep -v yast",
          Ops.get_string(@ServerSettings, "directory", "").shellescape
        )
        ret = Convert.to_map(SCR.Execute(path(".target.bash_output"), f))
        found = Builtins.splitstring(Ops.get_string(ret, "stdout", ""), "\n")
        found = Builtins.filter(found) { |s| s != "" }
        found = Builtins.filter(found) do |file|
          d = File.dirname(file)
          media = Builtins.sformat("%1/media.1/media", d)
          SCR.Read(path(".target.size"), media) != -1
        end
        Builtins.y2debug("media: %1", found)
        return deep_copy(found)
      else
        return []
      end
    end

    def FindAvailable
      _Available = {}
      Builtins.foreach(@Detected) do |c|
        ret = ReadContentFile(c)
        d = File.dirname(c)
        config_name = File.basename(d)
        if ret != {} && !Builtins.haskey(@Configs, config_name)
          Ops.set(_Available, d, ret)
        end
      end
      deep_copy(_Available)
    end

    def NFSExported(dir)
      nfs_config = Convert.to_map(ReadServiceSettings("nfs_server_auto"))
      exports = Ops.get_list(nfs_config, "nfs_exports", [])

      ret = false

      Builtins.foreach(exports) do |e|
        ret = true if Ops.get_string(e, "mountpoint", "") == dir
      end


      Builtins.y2milestone("Directory %1 is exported: %2", dir, ret)

      ret
    end

    def NFSValid(config)
      config = deep_copy(config)
      dir = Ops.get_string(config, "directory", "")

      if dir == nil || dir == ""
        Builtins.y2milestone("Empty or missing directory in the configuration")
        return false
      end

      # is the directory in /etc/exports?
      return false if !NFSExported(dir)

      nfsserver_running = Service.Status(NFS_SERVER_SERVICE) == 0
      Builtins.y2milestone("NFS server running: %1", nfsserver_running)

      # is the nfsserver running?
      nfsserver_running
    end

    def FTPValid(config)
      config = deep_copy(config)
      if vsftpd_is_standalone
        # is the service running?
        ret2 = Service.Status("vsftpd") == 0
        Builtins.y2milestone("FTP (vsftpd) server running: %1", ret2)

        return ret2
      end

      socket && socket.listening?
    end

    def HTTPValid(config)
      config = deep_copy(config)
      config = "/etc/apache2/conf.d/inst_server.conf"

      # is the config missing
      config_size = Convert.to_integer(SCR.Read(path(".target.size"), config))
      Builtins.y2milestone("Size of %1: %2", config, config_size)

      if Ops.less_or_equal(config_size, 0)
        Builtins.y2warning("Missing config file: %1", config)
        return false
      end

      # is the service running?
      ret = Service.Status("apache2") == 0
      Builtins.y2milestone("HTTP server running: %1", ret)

      ret
    end

    def ServiceValid(config)
      config = deep_copy(config)
      service = Ops.get_symbol(config, "service", :unknown)

      if service == :nfs
        return NFSValid(config)
      elsif service == :ftp
        return FTPValid(config)
      elsif service == :http
        return HTTPValid(config)
      end

      Builtins.y2warning(
        "Unknown service type %1, cannot check configuration",
        service
      )

      false
    end

    # Read all instserver settings
    # @return true on success
    def Read
      # Instserver read dialog caption
      caption = _("Initializing Configuration")
      steps = 4

      # We do not set help text here, because it was set outside
      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/2
          _("Read configuration file"),
          # Progress stage 2/2
          _("Search for a new repository")
        ],
        [
          # Progress step 1/2
          _("Reading configuration file..."),
          # Progress step 2/2
          _("Searching for a new repository..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      # read database
      return false if Abort()
      Progress.NextStage
      c = {}

      if SCR.Read(path(".target.size"), @ConfigFile) != -1
        c = XML.XMLToYCPFile(@ConfigFile)
        # TRANSLATORS: Error message
        Report.Error(_("Cannot read current settings.")) unless c
      end

      all = Ops.get_list(c, "configurations", [])
      @ServerSettings = Ops.get_map(c, "servers", {})

      @Configs = Builtins.listmap(all) do |i|
        name = Ops.get_string(i, "name", "")
        { name => i }
      end
      Builtins.y2milestone("Configs: %1", @Configs)

      @ServerSettings = Ops.get_map(c, "servers", {})
      Builtins.y2milestone("Server config: %1", @ServerSettings)

      # check the server status here
      if @ServerSettings.empty? || !ServiceValid(@ServerSettings)
        @FirstDialog = "settings"
      end

      firewalld.read

      # read current settings
      return false if Abort()
      Progress.NextStage

      @Detected = DetectMedia()

      # Progress finished
      Progress.NextStage

      @modified = false
      true
    end

    # Prepare map for writing  into XML
    # @return [Array]s of configurations
    def PrepareConfigs
      c = Builtins.maplist(@Configs) { |k, v| v }
      deep_copy(c)
    end

    # Write all instserver settings
    # @return true on success
    def Write
      Builtins.y2debug("Instserver::Write() called")

      # Instserver read dialog caption
      caption = _("Saving Installation Server Configuration")
      steps = 2

      # We do not set help text here, because it was set outside
      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/2
          _("Write the settings"),
          # Progress stage 2/2
          _("Run SuSEconfig")
        ],
        [
          # Progress step 1/2
          _("Writing the settings..."),
          # Progress step 2/2
          _("Running SuSEconfig..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      # write settings
      return false if Abort()
      Progress.NextStage

      c = PrepareConfigs()
      xml = { "configurations" => c, "servers" => @ServerSettings }
      ret = XML.YCPToXMLFile(:instserver, xml, @ConfigFile)

      # Error message
      Report.Error(_("Cannot write settings.")) unless ret

      # run SuSEconfig
      return false if Abort()
      Progress.NextStage

      slpreload = false

      regs_delete = deep_copy(@to_delete)

      # remove the deleted repositories
      Builtins.foreach(regs_delete) do |c2|
        dir = Ops.add(
          Ops.add(Ops.get_string(@ServerSettings, "directory", ""), "/"),
          c2
        )
        Builtins.y2milestone("removing directory: %1", dir)
        rm = Ops.add("/usr/bin/rm -rf ", dir.shellescape)
        SCR.Execute(path(".target.bash"), rm)
      end

      # add disabled SLP repositories
      Builtins.foreach(@Configs) do |confname, conf|
        if Ops.get_boolean(conf, "slp", true) == false
          regs_delete = Builtins.add(
            regs_delete,
            Ops.get_string(conf, "name", "")
          )
        end
      end

      # Remove the SLP files of removed or SLP disabled repositories
      Builtins.foreach(regs_delete) do |c2|
        regfile = Builtins.sformat("/etc/slp.reg.d/YaST-%1.reg", c2)
        if Ops.greater_than(SCR.Read(path(".target.size"), regfile), 0)
          slpreload = true
          SCR.Execute(path(".target.remove"), regfile)
        end
      end

      # Write all SLP files
      Builtins.foreach(@Configs) do |cn, cm|
        if Ops.get_boolean(cm, "slp", false)
          regfile = Builtins.sformat(
            "/etc/slp.reg.d/YaST-%1.reg",
            Ops.get_string(cm, "name", "")
          )
          WriteSLPReg(cm)
          slpreload = true
        end
      end

      # move content of the renamed repositories
      Builtins.foreach(@renamed) do |orig, new|
        # remove old reg file
        old_regfile = Builtins.sformat("/etc/slp.reg.d/YaST-%1.reg", orig)
        Builtins.y2milestone("removing old reg file: %1", old_regfile)
        SCR.Execute(path(".target.bash"), "/usr/bin/rm -f #{old_regfile.shellescape}")
        # rename the directory
        cmd = Builtins.sformat(
          "/usr/bin/mv %1/%2 %1/%3",
          Ops.get_string(@ServerSettings, "directory", "").shellescape,
          orig.shellescape,
          new.shellescape
        )
        Builtins.y2milestone("moving directory: %1", cmd)
        if SCR.Execute(path(".target.bash"), cmd) != 0
          Popup.Error(_("Error while moving repository content."))
          next
        end
      end

      return false if Abort()

      # slp service reload is required - the configuration has been changed
      if slpreload
        if Service.Status("slpd") == 0
          Service.Restart("slpd")
        else
          Service.Start("slpd")
        end
      end

      # Progress finished
      Progress.NextStage

      true
    end

    def UpdateConfig
      Builtins.y2debug("current config: %1", @Configs)

      name = Ops.get_string(@Config, "name", "")
      old_name = Ops.get_string(@Config, "old_name", "")

      # remove the old config
      if Builtins.haskey(@Configs, old_name) && old_name != ""
        @Configs = Builtins.filter(@Configs) { |k, v| k != old_name }
        Builtins.remove(@Config, "old_name")
      end

      if name != ""
        # update the config
        Ops.set(@Configs, name, @Config)
      end

      Builtins.y2debug("current config: %1", @Configs)
      nil
    end


    # Create XML Configuration
    # @return [void]
    def configSetup
      doc = {}
      Ops.set(doc, "listEntries", {})
      Ops.set(doc, "cdataSections", [])
      Ops.set(doc, "rootElement", "instserver")
      Ops.set(doc, "systemID", "/usr/share/YaST2/dtd/instserver.dtd")
      Ops.set(doc, "nameSpace", "http://www.suse.com/1.0/yast2ns")
      Ops.set(doc, "typeNamespace", "http://www.suse.com/1.0/configns")
      XML.xmlCreateDoc(:instserver, doc)
      nil
    end


    # Get all instserver settings from the first parameter
    # (For use by autoinstallation.)
    # @param [Hash] settings The YCP structure to be imported.
    # @return [Boolean] True on success
    def Import(settings)
      settings = deep_copy(settings)
      true
    end

    # Dump the instserver settings to a single map
    # (For use by autoinstallation.)
    # @return [Hash] Dumped settings (later acceptable by Import ())
    def Export
      {}
    end




    # Create a textual summary and a list of unconfigured cards
    # @return summary of the current configuration
    def Summary
      # Configuration summary text for autoyast
      sum = ""
      _Available = Builtins.filter(FindAvailable()) do |d, avail|
        !Builtins.haskey(@Configs, File.basename(d))
      end
      unconf = Builtins.maplist(_Available) do |d, avail|
        dir = File.basename(d)
        Item(
          Id(dir),
          Ops.add(
            Ops.add(
              Ops.add(Ops.get_string(avail, "LABEL", ""), "("),
              Ops.get_string(avail, "DEFAULTBASE", "")
            ),
            ")"
          )
        )
      end

      sum = Summary.AddHeader(sum, _("Configured Repositories"))
      sum = Summary.OpenList(sum)

      Builtins.foreach(@Configs) do |name, cfg|
        source = Ops.add(
          Ops.add(Ops.get_string(cfg, "LABEL", ""), "<br><b>Architecture: </b>"),
          Ops.get_string(cfg, "DEFAULTBASE", "")
        )
        sum = Summary.AddListItem(sum, source)
      end
      sum = Summary.CloseList(sum)
      [sum, unconf]
    end

    # Create an overview table with all configured data
    # @return table items
    def Overview
      Builtins.y2milestone("Configs: %1", @Configs)
      overview = Builtins.maplist(@Configs) do |name, cfg|
        Item(
          Id(name),
          name,
          Ops.add(
            Ops.add(Ops.get_string(cfg, "PRODUCT", ""), " "),
            Ops.get_string(cfg, "VERSION", "")
          )
        )
      end
      deep_copy(overview)
    end


    # Constructor
    def Instserver
      configSetup

      nil
    end

    # Convenience method for optaining the vsftpd systemd socket
    def socket
      Yast2::Systemd::Socket.find("vsftpd.socket")
    end

    publish :variable => :is_service_pack, :type => "boolean"
    publish :variable => :test, :type => "boolean"
    publish :variable => :Config, :type => "map <string, any>"
    publish :variable => :Configs, :type => "map <string, map <string, any>>"
    publish :variable => :ServerSettings, :type => "map"
    publish :variable => :Rep, :type => "string"
    publish :variable => :FirstDialog, :type => "string"
    publish :variable => :products, :type => "list <map>"
    publish :variable => :Detected, :type => "list <string>"
    publish :variable => :standalone, :type => "boolean"
    publish :variable => :renamed, :type => "map <string, string>"
    publish :function => :Modified, :type => "boolean ()"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :to_delete, :type => "list <string>"
    publish :variable => :AbortFunction, :type => "boolean"
    publish :function => :Abort, :type => "boolean ()"
    publish :function => :createLinks, :type => "list <string> (string, string, list <string>)"
    publish :function => :createOrderFiles, :type => "boolean (string)"
    publish :function => :InstallFTPPackages, :type => "boolean ()"
    publish :function => :SetupFTP, :type => "boolean (string, string, string)"
    publish :function => :InstallHTTPPackages, :type => "boolean ()"
    publish :function => :SetupHTTP, :type => "boolean (string, string)"
    publish :function => :SetupNFS, :type => "boolean (string, string)"
    publish :function => :GetIPAddr, :type => "string ()"
    publish :function => :GetHostname, :type => "string ()"
    publish :function => :WriteSLPReg, :type => "boolean (map <string, any>)"
    publish :function => :DetectMedia, :type => "list <string> ()"
    publish :function => :FindAvailable, :type => "map <string, map> ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :UpdateConfig, :type => "void ()"
    publish :function => :configSetup, :type => "void ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Summary, :type => "list ()"
    publish :function => :Overview, :type => "list ()"
    publish :function => :Instserver, :type => "void ()"
  end

  Instserver = InstserverClass.new
  Instserver.main
end
