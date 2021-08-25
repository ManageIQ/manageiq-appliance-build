namespace :release do
  desc "Tasks to run on a new branch when a new branch is created"
  task :new_branch do
    require 'pathname'

    branch = ENV["RELEASE_BRANCH"]
    if branch.nil? || branch.empty?
      STDERR.puts "ERROR: You must set the env var RELEASE_BRANCH to the proper value."
      exit 1
    end

    current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
    if current_branch == "master"
      STDERR.puts "ERROR: You cannot do new branch tasks from the master branch."
      exit 1
    end

    root = Pathname.new(__dir__).join("../..")

    # Modify nightly-build.sh
    nightly_build = root.join("bin", "nightly-build.sh")
    content = nightly_build.read
    nightly_build.write(content.sub(/^(BRANCH=).+/, "\\1#{branch}"))

    # Modify vsphere ova
    vsphere_ova = root.join("config", "ova.json")
    content = vsphere_ova.read
    vsphere_ova.write(content.sub(/("vsphere_product_version": ")[^"]+(")/, "\\1#{branch}\\2"))

    # Commit
    files_to_update = [nightly_build, vsphere_ova]
    exit $?.exitstatus unless system("git add #{files_to_update.join(" ")}")
    exit $?.exitstatus unless system("git commit -m 'Changes for new branch #{branch}'")

    puts
    puts "The commit on #{current_branch} has been created."
    puts "Run the following to push to the upstream remote:"
    puts
    puts "\tgit push upstream #{current_branch}"
    puts
  end

  desc "Tasks to run on the master branch when a new branch is created"
  task :new_branch_master do
    require 'pathname'

    branch = ENV["RELEASE_BRANCH"]
    if branch.nil? || branch.empty?
      STDERR.puts "ERROR: You must set the env var RELEASE_BRANCH to the proper value."
      exit 1
    end

    next_branch = ENV["RELEASE_BRANCH_NEXT"]
    if next_branch.nil? || next_branch.empty?
      STDERR.puts "ERROR: You must set the env var RELEASE_BRANCH_NEXT to the proper value."
      exit 1
    end

    current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
    if current_branch != "master"
      STDERR.puts "ERROR: You cannot do master branch tasks from a non-master branch (#{current_branch})."
      exit 1
    end

    root = Pathname.new(__dir__).join("../..")

    next_branch_number = next_branch[0].ord - 96
    rpm_repo_name = "#{next_branch_number}-#{next_branch}"

    # Modify main kickstart repos
    main_ks_repos = root.join("kickstarts", "partials", "main", "repos.ks.erb")
    content = main_ks_repos.read
    content.gsub!(/(manageiq-)\d+-\w+/, "\\1#{rpm_repo_name}")
    content.gsub!(%r{(/rpm.manageiq.org/release/)\d+-\w+}, "\\1#{rpm_repo_name}")
    main_ks_repos.write(content)

    # Commit
    files_to_update = [main_ks_repos]
    exit $?.exitstatus unless system("git add #{files_to_update.join(" ")}")
    exit $?.exitstatus unless system("git commit -m 'Changes after new branch #{branch}'")

    puts
    puts "The commit on #{current_branch} has been created."
    puts "Run the following to push to the upstream remote:"
    puts
    puts "\tgit push upstream #{current_branch}"
    puts
  end
end
