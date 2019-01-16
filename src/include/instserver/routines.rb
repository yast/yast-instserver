# encoding: utf-8

# File:	include/instserver/routines.rb
# Package:	Configuration of instserver
# Summary:	Helper methods
# Authors:	Anas Nashif <nashif@suse.de>
#
module Yast
  module InstserverRoutinesInclude
    include Yast::Logger

    def initialize_instserver_routines(include_target)
      textdomain "instserver"
    end

    def ReadMediaFile(media)
      if SCR.Read(path(".target.size"), media) != -1
        media_contents = Convert.to_string(
          SCR.Read(path(".target.string"), media)
        )
        m = Builtins.splitstring(media_contents, "\n")
        return deep_copy(m)
      else
        return []
      end
    end

    # Split CPE id and distro label (separated by comma)
    # Be extra careful as there might be commas in the CPE string itself (bsc#1122003).
    # @param [String] distro "DISTRO" value from content file
    # @return [Array<String,String>]
    #
    # The distro arg could look like
    #   "cpe:/o:suse:sles:12,SUSE Linux Enterprise Server 12"
    #   "cpe:/o:suse:sles:12:sp3,SUSE Linux Enterprise Server 12 SP3"
    #   "cpe:/o:novell,inc:sles:12:sp3,SUSE Linux Enterprise Server 12 SP3"
    #
    # The match below assumes the cpe string are fields containing no white
    # space separated by ':' optionally followed by a ',' and an arbitrary
    # product name.
    #
    # For the CPE format specs see http://cpe.mitre.org.
    #
    def distro_split(distro)
      distro.match(/((?:[^:\s]*:)+[^,]*),?(.*)?/) do |m|
        return m[1, 2]
      end

      [distro, '']
    end

    # Split CPE ID and distro label (separated by comma)
    # @param [String] distro "DISTRO" value from content file
    # @return [Hash<String,String>,nil] parsed value, map: { "name" => <string>, "cpeid" => <string> }
    #    or nil if the input value is nil or does not contain a comma
    def distro_map(distro)
      if !distro
        log.warn "Received nil distro value"
        return nil
      end

      cpeid, name = distro_split(distro)

      if name.empty?
        log.warn "Cannot parse DISTRO value: #{distro}"
        return nil
      end

      { "cpeid" => cpeid, "name" => name }
    end

    def ReadContentFile(content)
      Builtins.y2debug("Reading content %1", content)

      contentmap = SCR.Read(path(".content_file"), content)
      contentmap.values.each(&:strip!)

      # "DISTRO" flag is used in SLE12, "NAME" and "LABEL" are missing
      # format: "<cpeid>,<product_name>", CPE ID is defined here:
      # http://csrc.nist.gov/publications/nistir/ir7695/NISTIR-7695-CPE-Naming.pdf
      distro = contentmap["DISTRO"]

      if distro
        distro_values = distro_map(distro)

        if distro_values
          # name is displayed in overview
          contentmap["NAME"] = distro_values["name"]
          # label is written to SLP config
          contentmap["LABEL"] = distro_values["name"].dup

          contentmap["CPEID"] = distro_values["cpeid"]
        end
      end

      Builtins.y2milestone("Read content file %1: %2", content, contentmap)

      contentmap
    end

  end
end
