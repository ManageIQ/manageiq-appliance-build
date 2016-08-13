module Build
  module KickstartHelpers

    def git_checkout(checkout, directory)
      if checkout.ref == checkout.branch
        git_checkout_branch(checkout, directory)
      else
        git_checkout_tag(checkout, directory)
      end
    end

    private

    def git_checkout_branch(checkout, directory)
      <<-EOM
        rm -rf #{directory}
        mkdir -p #{directory}
        git clone #{checkout.remote} #{directory}
        pushd #{directory}
          git checkout #{checkout.branch}
          git reset --hard #{checkout.commit_sha}
        popd
      EOM
    end

    def git_checkout_tag(checkout, directory)
      <<-EOM
        rm -rf #{directory}
        mkdir -p #{directory}
        git clone --depth 1 --branch #{checkout.ref} #{checkout.remote} #{directory}
        pushd #{directory}
          git config remote.origin.fetch '+refs/heads/*:refs/remote/origin/*'
          git config branch.#{checkout.branch}.remote origin
          git config branch.#{checkout.branch}.merge refs/heads/#{checkout.branch}
          git checkout -b #{checkout.branch}
        popd
      EOM
    end

  end
end
