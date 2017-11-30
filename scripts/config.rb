require 'pathname'

BUILD_BASE          = Pathname.new("/build")
GPG_DIR             = Pathname.new("/root/.gnupg")
CFG_DIR             = BUILD_BASE.join("config")
CREDS_DIR           = CFG_DIR.join("creds")
FILESHARE_DIR       = BUILD_BASE.join("fileshare")
REFS_DIR            = BUILD_BASE.join("references")
IMGFAC_DIR          = BUILD_BASE.join("imagefactory")
IMGFAC_CONF         = CFG_DIR.join("imagefactory.conf")
STORAGE_DIR         = BUILD_BASE.join("storage")

FILE_SERVER         = ENV["BUILD_FILE_SERVER"]             # SSH Server to host files
FILE_SERVER_ACCOUNT = ENV["BUILD_FILE_SERVER_ACCOUNT"]     # Account to SSH as
FILE_SERVER_BASE    = Pathname.new(ENV["BUILD_FILE_SERVER_BASE"] || ".") # Subdirectory of Account where to store builds
