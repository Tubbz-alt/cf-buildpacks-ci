class BuildpackDependencyUpdater::Node < BuildpackDependencyUpdater
  def dependency_version_currently_in_manifest?
    dependencies = buildpack_manifest['dependencies']
    dependencies.select do |dep|
      dep['name'] == dependency &&
      dep['version'] == dependency_version &&
      dep['uri'] == uri
    end.count > 0
  end

  def newer_dependency_version_currently_in_manifest?
    false
  end

  def perform_dependency_update
    major_version, _, _ = dependency_version.split(".")

    dependencies_with_same_major_version = buildpack_manifest["dependencies"].select do |dep|
      dep["name"] == dependency && dep["version"].split(".").first == major_version
    end.map do |dep|
      Gem::Version.new(dep['version'])
    end

    if dependencies_with_same_major_version.count > 1 || (buildpack != 'nodejs')
      version_to_delete = dependencies_with_same_major_version.sort.first.to_s
    else
      version_to_delete = nil
    end

    original_dependencies = buildpack_manifest["dependencies"].clone
    new_dependencies = buildpack_manifest["dependencies"].clone

    if buildpack == "nodejs" || (buildpack == "ruby" && %w(4 6).include?(major_version)) || (buildpack == 'dotnet-core' && major_version == '6')
      new_dependencies = buildpack_manifest["dependencies"].delete_if { |dep| dep["name"] == dependency && dep['cf_stacks'].include?(stack_name) && dep["version"] == version_to_delete }
      dependency_hash = {
        "name" => dependency,
        "version" => dependency_version,
        "uri" => uri,
        "sha256" => sha256,
        "md5" => md5,
        "cf_stacks" => [stack_name]
      }
      buildpack_manifest["dependencies"] << dependency_hash
    end

    @removed_versions = (original_dependencies - new_dependencies).map{|dep| dep['version']} unless new_dependencies == original_dependencies
  end

  def perform_dependency_specific_changes
    major_version, _minor_version, _ = dependency_version.split(".")

    # Make latest node 4.x.y version default node version for nodejs buildpack
    # Make latest node 6.x.y version default node version for dotnet-core buildpack
    update_default_versions = (buildpack == "nodejs" && major_version == "4") ||
                              (buildpack == 'dotnet-core' && major_version == '6')

    if update_default_versions
      perform_default_versions_update
    end
  end
end
