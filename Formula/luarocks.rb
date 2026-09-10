class Luarocks < Formula
  desc "Package manager for the Lua programming language (sandbox-patched)"
  homepage "https://luarocks.org/"
  url "https://luarocks.org/releases/luarocks-3.13.0.tar.gz"
  sha256 "245bf6ec560c042cb8948e3d661189292587c5949104677f1eecddc54dbe7e37"
  license "MIT"
  revision 1
  compatibility_version 1
  head "https://github.com/luarocks/luarocks.git", branch: "main"

  livecheck do
    url :homepage
    regex(%r{/luarocks[._-]v?(\d+(?:\.\d+)+)\.t}i)
  end

  depends_on "luajit" => :test
  depends_on "lua"

  uses_from_macos "unzip"

  # Patch the config sandbox to expose standard Lua libraries
  # (table, string, io, os, math, etc.) to user config files.
  # The sandbox in persist.lua for remote rockspec/manifest loading
  # is NOT touched — only local config files are unsealed.
  patch :DATA

  def install
    ENV.deparallelize

    system "./configure", "--prefix=#{prefix}",
                          "--sysconfdir=#{etc}",
                          "--rocks-tree=#{HOMEBREW_PREFIX}"
    system "make", "install"
    generate_completions_from_executable(bin/"luarocks", "completion")

    luaversion = Formula["lua"].version.major_minor
    inreplace_files = %w[
      cmd/config
      cmd/which
      core/cfg
      deps
    ].map { |file| share/"lua"/luaversion/"luarocks/#{file}.lua" }
    inreplace inreplace_files, "/usr/local", HOMEBREW_PREFIX
  end

  test do
    luas = [
      Formula["lua"],
      Formula["luajit"],
    ]

    luas.each do |lua|
      luaversion, luaexec = case lua.name
      when "luajit" then ["5.1", lua.opt_bin/"luajit"]
      else [lua.version.major_minor, lua.opt_bin/"lua-#{lua.version.major_minor}"]
      end

      ENV["LUA_PATH"] = "#{testpath}/share/lua/#{luaversion}/?.lua"
      ENV["LUA_CPATH"] = "#{testpath}/lib/lua/#{luaversion}/?.so"

      system bin/"luarocks", "install", "luafilesystem", "--tree=#{testpath}", "--lua-dir=#{lua.opt_prefix}"
      system luaexec, "-e", "require('lfs')"

      case luaversion
      when "5.1"
        (testpath/"lfs_#{luaversion}test.lua").write <<~LUA
          require("lfs")
          lfs.mkdir("blank_space")
        LUA

        system luaexec, "lfs_#{luaversion}test.lua"
        assert_predicate testpath/"blank_space", :directory?,
          "Luafilesystem failed to create the expected directory"
      else
        (testpath/"lfs_#{luaversion}test.lua").write <<~LUA
          require("lfs")
          print(lfs.currentdir())
        LUA

        assert_match testpath.to_s, shell_output("#{luaexec} lfs_#{luaversion}test.lua")
      end
    end
  end
end

__END__
--- a/src/luarocks/core/cfg.lua
+++ b/src/luarocks/core/cfg.lua
@@ -102,6 +102,35 @@
             print(util.show_table(e, "global environment"))
          end,
       }
+      -- Expose standard Lua libraries to config files.
+      -- The sandbox in persist.lua is kept for remote rockspec/manifest loading,
+      -- but user-authored config files are trusted local code and should be
+      -- able to use table.insert, string.match, io.open, etc.
+      e.table        = table
+      e.string       = string
+      e.io           = io
+      e.os           = os
+      e.math         = math
+      e.pairs        = pairs
+      e.ipairs       = ipairs
+      e.tostring     = tostring
+      e.tonumber     = tonumber
+      e.type         = type
+      e.error        = error
+      e.pcall        = pcall
+      e.xpcall       = xpcall
+      e.print        = print
+      e.select       = select
+      e.next         = next
+      e.assert       = assert
+      e.setmetatable = setmetatable
+      e.getmetatable = getmetatable
+      e.rawget       = rawget
+      e.rawset       = rawset
+      e.rawequal     = rawequal
+      e.rawlen       = rawlen
+      e.unpack       = unpack
+      e.require      = require
       return e
    end

@@ -110,6 +139,32 @@
       -- remove some stuff we do not want to integrate
       overrides.os_getenv = nil
       overrides.dump_env = nil
+      -- remove injected standard libraries (used by config file, not part of cfg)
+      overrides.table        = nil
+      overrides.string       = nil
+      overrides.io           = nil
+      overrides.os           = nil
+      overrides.math         = nil
+      overrides.pairs        = nil
+      overrides.ipairs       = nil
+      overrides.tostring     = nil
+      overrides.tonumber     = nil
+      overrides.type         = nil
+      overrides.error        = nil
+      overrides.pcall        = nil
+      overrides.xpcall       = nil
+      overrides.print        = nil
+      overrides.select       = nil
+      overrides.next         = nil
+      overrides.assert       = nil
+      overrides.setmetatable = nil
+      overrides.getmetatable = nil
+      overrides.rawget       = nil
+      overrides.rawset       = nil
+      overrides.rawequal     = nil
+      overrides.rawlen       = nil
+      overrides.unpack       = nil
+      overrides.require      = nil
       -- remove tables to be copied verbatim instead of deeply merged
       if overrides.rocks_trees   then cfg.rocks_trees   = nil end
       if overrides.rocks_servers then cfg.rocks_servers = nil end
