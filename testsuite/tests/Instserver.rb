# encoding: utf-8

module Yast
  class InstserverClient < Client
    def main
      # testedfiles: Instserver.ycp

      Yast.include self, "testsuite.rb"
      TESTSUITE_INIT([], nil)

      Yast.import "Instserver"

      DUMP("Instserver::Modified")
      TEST(lambda { Instserver.Modified }, [], nil)

      DUMP("Instserver::EscapeSLPData()")
      TEST(lambda do
        Instserver.EscapeSLPData(
          { "description" => "No need to escpace anything." }
        )
      end, [], nil)
      TEST(lambda do
        Instserver.EscapeSLPData(
          {
            "description" => "Rounded brackets (), \\ backslash and comma , must be escpaced."
          }
        )
      end, [], nil)
      TEST(lambda do
        Instserver.EscapeSLPData({ "escaped.=name" => "value\\\\\\." })
      end, [], nil)

      nil
    end
  end
end

Yast::InstserverClient.new.main
