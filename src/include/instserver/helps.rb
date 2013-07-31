# encoding: utf-8

# File:	include/instserver/helps.ycp
# Package:	Configuration of installation server
# Summary:	Help texts of all the dialogs
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  module InstserverHelpsInclude
    def initialize_instserver_helps(include_target)
      textdomain "instserver"

      # All helps are here
      @HELPS = {
        "server"   => _(
          "<p><b><big>Network Server Configuration</big></b><br>\n</p>"
        ) +
          _(
            "<p>Select one of the server options and specify where all the repositories\n" +
              "should be hosted on the local system.\n" +
              "</p>"
          ) +
          _(
            "<p>If you have one of the services already running and want to do the\n" +
              "server configuration manually, select not to configure \n" +
              "the services.\n" +
              "</p>\n"
          ),
        "nfs"      => _(
          "<p><b><big>NFS Server Configuration</big></b><br>\n</p>"
        ) +
          _(
            "<p>To complete this configuration, a new entry in the file\n" +
              "<em>/etc/exports</em> must be added and the NFS server must be \n" +
              "installed and started.\n" +
              "</p>\n"
          ) +
          _(
            "<p>If you need to restrict access to the exported directories to certain \n" +
              "hosts, add a more restrictive wild card mask. For example, use <em>192.168.1.0/24</em>\n" +
              "to restrict access to the <em>192.168.1.0</em> subnet.\n" +
              "</p>\n"
          ) +
          _(
            "<p>Additionally, set the export options. For more details about the available\n" +
              "options, see the manual page for <em>exports</em> (man exports(5))\n" +
              "</p>\n"
          ) +
          _(
            "<p>The repository will be available at the following URL:\n<tt>nfs://Host_IP/Repository_Name</tt></p>"
          ),
        "ftp"      => _(
          "<p><b><big>FTP Server Configuration</big></b><br>\n</p>"
        ) +
          _(
            "<p>To complete this configuration, an FTP server must be \ninstalled and started.</p>\n"
          ) +
          _(
            "<p>If the chosen software repository directory is outside\n" +
              "the FTP server hierarchy, a mount entry is added to <tt>/etc/fstab</tt>.\n" +
              "This makes the software repository directory available under the\n" +
              "FTP server (using the <tt>--bind</tt> option of <tt>mount</tt>).\n" +
              "</p>\n"
          ) +
          _(
            "<p>The installation server will be available to clients using the following URL:\n</p>\n"
          ) +
          _("<p><tt>ftp://&lt;Host IP&gt;/&lt;Repository Name&gt;</tt>\n</p>"),
        "http"     => _(
          "<p><b><big>HTTP Server Configuration</big></b><br>\n</p>"
        ) +
          _(
            "<p>To complete this configuration, an HTTP server must be \n" +
              "installed and started. The alias will be used to reference the installation\n" +
              "server root directory.</p>\n"
          ) +
          _(
            "<p>Select a short and easy to remember alias. For example, if you select\n<em>SUSE</em> as the alias, the repositories will be available as shown below:</p>\n"
          ) +
          _(
            "<p><tt>http://&lt;Host IP&gt;/SUSE/&lt;Repository Name&gt;</tt>\n</p>"
          ),
        "initial"  => _("<p><b>Configuration of the Repository</b><br>\n</p>\n") +
          _(
            "<p>The repository name is used to create a directory under which all product\n" +
              "CDs are copied and managed. The repository is accessed using the\n" +
              "configured protocol (NFS, FTP, or HTTP).</p> \n"
          ) +
          _("<p><b><big>SLP Support</big></b></p>") +
          _(
            "<p>SLP (Service Location Protocol) facilitates finding an installation server. \nIf checked, the repository will be announced on the network using SLP.</p>\n"
          ),
        "initial2" => _("<p><b>Configuration of the Repository</b><br>\n</p>\n") +
          _(
            "<p>Select a source drive from the list, insert the first medium of a base product, and press\n<b>Next</b> to copy the content into the local repository.</p>\n"
          ) +
          _(
            "<p>When the base media are copied to the local repository, you can add additional\nCDs to the repository (for example, Service Pack CDs or any add-on CDs).</p>\n"
          ) +
          _("<p><b><big>ISO Images</big></b></p>") +
          _(
            "<p>ISO images can be used instead of CD or DVD media. If you press <b>Next</b>, you can\nselect ISO image files.</p>\n"
          ),
        # Read dialog help 1/2
        "read"     => _(
          "<p><b><big>Initializing Configuration</big></b><br>\nPlease wait...<br></p>\n"
        ) +
          # Read dialog help 2/2
          _(
            "<p><b><big>Aborting Initialization:</big></b><br>\nSafely abort the configuration utility by pressing <b>Abort</b> now.</p>\n"
          ),
        # Write dialog help 1/2
        "write"    => _(
          "<p><b>Saving Repository Configuration</b><br>\n</p>\n"
        ) +
          # Write dialog help 2/2
          _(
            "<p><b><big>Aborting Saving:</big></b><br>\n" +
              "Abort the save procedure by pressing <b>Abort</b>.\n" +
              "An additional dialog informs whether it is safe to do so.\n" +
              "</p>\n"
          ),
        # Summary dialog help 1/3
        "summary"  => _(
          "<p><b>Repository Configuration</b><br>\nConfigure the installation server here.<br></p>\n"
        ) +
          # Summary dialog help 2/3
          _(
            "<p><b>Adding a Repository:</b><br>\n" +
              "Unconfigured directories are detected in the repository directory and then made \n" +
              "available for configuration.\n" +
              "To add a repository, select it from the list of unconfigured repositories and press <b>Configure</b>.</p>\n"
          ) +
          # Summary dialog help 3/3
          _(
            "<p><b><big>Editing or Deleting:</big></b><br>\n" +
              "If you press <b>Edit</b>, an additional dialog in which to change\n" +
              "the configuration opens.</p>\n"
          ),
        # Ovreview dialog help 1/3
        "overview" => _(
          "<p><b>Repositories Overview</b><br>\n" +
            "Get an overview of the configured repositories and edit their \n" +
            "configuration if necessary.<br></p>\n"
        ) +
          # Ovreview dialog help 2/3
          _(
            "<p><b>Adding a Repository:</b><br>\nPress <b>Add</b> to configure a repository.</p>\n"
          ) +
          # Ovreview dialog help 3/3
          _(
            "<p><b><big>Editing or Deleting:</big></b><br>\n" +
              "Choose the repository you want to change or remove and\n" +
              "press  <b>Edit</b> or <b>Delete</b>, respectively.</p>\n"
          )
      } 

      # EOF
    end
  end
end
