use_frameworks!
inhibit_all_warnings!
platform :ios, '15.0'

target 'MapsIndoorsMapboxNewerBuild' do
  # Comment the next line if you don't want to use dynamic frameworks
  #use_frameworks!
  #pod 'MapsIndoorsMapbox', '4.0.2'
  # Pods for MapsIndoorsMapboxNewerBuild
  pod 'MapsIndoors', :path => './'
  pod 'MapsIndoorsCore', :path => './'
  pod 'MapsIndoorsMapbox', :path => './'
end

PROJECT_ROOT_DIR = File.dirname(File.expand_path(__FILE__))
PODS_DIR = File.join(PROJECT_ROOT_DIR, 'Pods')
PODS_TARGET_SUPPORT_FILES_DIR = File.join(PODS_DIR, 'Target Support Files')

post_install do |pi|
  # Avoid warnings like this from pods project:
  #   The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 8.0, but the range of supported deployment target versions is 9.0 to 14.2.99.
  # We're setting deployment target '9.0' because the SDK lib target has this as it's target version;
  # setting to 12.0 as in the top of this file will generate warnings from the SDK
  # So when changing SDK deployment target, this should probably change as well...
  pi.pods_project.targets.each do |t|
    t.build_configurations.each do |bc|
      bc.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      bc.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
  end

   remove_static_framework_duplicate_linkage({
                                             'MapsIndoors_GoogleMaps' => ['GoogleMaps'],
                                             # 'MapsIndoors_Mapbox' => ['GoogleMaps', 'ValueAnimator']
                                             })
end


# CocoaPods provides the abstract_target mechanism for sharing dependencies between distinct targets.
# However, due to the complexity of our project and use of shared frameworks, we cannot simply bundle everything under
# a single abstract_target. Using a pod in a shared framework target and an app target will cause CocoaPods to generate
# a build configuration that links the pod's frameworks with both targets. This is not an issue with dynamic frameworks,
# as the linker is smart enough to avoid duplicate linkage at runtime. Yet for static frameworks the linkage happens at
# build time, thus when the shared framework target and app target are combined to form an executable, the static
# framework will reside within multiple distinct address spaces. The end result is duplicated symbols, and global
# variables that are confined to each target's address space, i.e not truly global within the app's address space.

def remove_static_framework_duplicate_linkage(static_framework_pods)
  puts "Removing duplicate linkage of static frameworks"

  Dir.glob(File.join(PODS_TARGET_SUPPORT_FILES_DIR, "Pods-*")).each do |path|
    pod_target = path.split('-', -1).last

    static_framework_pods.each do |target, pods|
      next if pod_target == target
      frameworks = pods.map { |pod| identify_frameworks(pod) }.flatten

      Dir.glob(File.join(path, "*.xcconfig")).each do |xcconfig|
        lines = File.readlines(xcconfig)

        if other_ldflags_index = lines.find_index { |l| l.start_with?('OTHER_LDFLAGS') }
          other_ldflags = lines[other_ldflags_index]

          frameworks.each do |framework|
            other_ldflags.gsub!("-framework \"#{framework}\"", '')
          end

          File.open(xcconfig, 'w') do |fd|
            fd.write(lines.join)
          end
        end
      end
    end
  end
end

def identify_frameworks(pod)
  frameworks = Dir.glob(File.join(PODS_DIR, pod, "**/*.framework")).map { |path| File.basename(path) }

  if frameworks.any?
    return frameworks.map { |f| f.split('.framework').first }
  end

  return pod
end
