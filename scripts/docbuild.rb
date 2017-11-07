require 'logger'
require 'pathname'
require 'fileutils'

$log = Logger.new(STDOUT)

BUILD_BASE     = Pathname.new("/build")
FILESHARE_DIR  = BUILD_BASE.join("fileshare")

DOCS_BRANCH    = "gaprindashvili"
DOCS_REPO      = BUILD_BASE.join("manageiq_docs")
DOCS_PACKAGE   = DOCS_REPO.join("_package/community", DOCS_BRANCH)
DOCS_FILESHARE = FILESHARE_DIR.join(DOCS_BRANCH, "latest-docs")

def execute(cmd)
  exit $?.exitstatus unless system(cmd)
end

$log.info("Packaging docs...")
FileUtils.rm_rf DOCS_REPO
Dir.chdir(BUILD_BASE) do
  execute("git clone https://github.com/ManageIQ/manageiq_docs")
  Dir.chdir("manageiq_docs") do
    execute("git checkout #{DOCS_BRANCH}")
    execute("bundle install")
    execute("bundle exec ascii_binder package")
  end
end
$log.info("Packaging docs...Complete")

$log.info("Copying docs to fileshare...")
FileUtils.rm_rf DOCS_FILESHARE
FileUtils.cp_r(DOCS_PACKAGE, DOCS_FILESHARE)
$log.info("Copying docs to fileshare...Complete")
