require "bundler/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require 'rake/baseextensiontask'
Class::new(Rake::BaseExtensionTask){
  def define_compile_tasks
    import File::join(@ext_dir, "Rakefile")
    
    ENV["RUBYLIBDIR"] ||= @lib_dir
    
    desc "Compile #{@name}"
    task "compile:#{@name}" => [:fetch_libs]
    
    desc "Compile all the extensions"
    task "compile" => ["compile:#{@name}"]
  end
}::new("cp2112"){|ext|
  ext.lib_dir = File::join("lib", ext.name)
}

task :default => :spec
