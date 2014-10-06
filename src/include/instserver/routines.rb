# encoding: utf-8

# File:	include/instserver/complex.ycp
# Package:	Configuration of instserver
# Summary:	Dialogs definitions
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  module InstserverRoutinesInclude
    def initialize_instserver_routines(include_target)

      textdomain "instserver"

      Yast.import "String"
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

    def ReadContentFile(content)
      Builtins.y2debug("Reading content %1", content)

      contentmap = Convert.convert(
        SCR.Read(path(".content_file"), content),
        :from => "any",
        :to   => "map <string, string>"
      )

      contentmap = Builtins.mapmap(contentmap) do |key, value|
        { key => String.CutBlanks(value) }
      end
      Builtins.y2milestone("Read content file %1: %2", content, contentmap)

      deep_copy(contentmap)
    end

  end
end
