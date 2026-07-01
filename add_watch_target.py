#!/usr/bin/env python3
"""
Add Watch App target to the Runner Xcode project using pbxproj library.
This script safely adds:
1. Watch App native target with proper build phases
2. Watch App build configurations (Debug/Release/Profile)
3. Watch App product reference
4. Embed Watch Content build phase in Runner target
"""

import sys
import os

# Install and use pbxproj
try:
    from pbxproj import XcodeProject
except ImportError:
    print("ERROR: pbxproj not installed. Run: pip install pbxproj")
    sys.exit(1)

PBXPROJ_PATH = '/Users/meixulin/Desktop/zaine-app/zaine_app/ios/Runner.xcodeproj/project.pbxproj'

def main():
    print(f"Loading project: {PBXPROJ_PATH}")
    project = XcodeProject.load(PBXPROJ_PATH)
    
    # Check current targets
    print("\nCurrent targets:")
    for target in project.objects.get_targets():
        print(f"  - {target.name} ({target.productType})")
    
    # Step 1: Add Watch App target
    print("\nAdding Watch App target...")
    watch_target = project.add_target(
        'ZaineWatch Watch App',
        product_type='com.apple.product-type.application.watchapp2',
        deployment_target='watchOS26.5'
    )
    
    if watch_target is None:
        print("ERROR: Failed to create Watch App target")
        sys.exit(1)
    
    print(f"  Created target: {watch_target.name} (UUID: {watch_target.id})")
    
    # Step 2: Add build configurations for Watch App
    print("\nAdding build configurations...")
    
    # Get Runner's build configuration list as reference
    runner_target = project.get_target_by_name('Runner')
    runner_config_list_id = runner_target.buildConfigurationList
    
    # Create configuration list for Watch App
    config_list = project.add_configuration_list(
        name='ZaineWatch Watch App',
        config_names=['Debug', 'Release', 'Profile']
    )
    watch_target.buildConfigurationList = config_list.id
    
    # Set build configuration values for Watch App
    for config_name in ['Debug', 'Release', 'Profile']:
        config_id = config_list[config_name]
        config = project.objects[config_id]
        
        # Watch App specific settings
        config['buildSettings'] = {
            'PRODUCT_NAME': '$(TARGET_NAME)',
            'PRODUCT_BUNDLE_IDENTIFIER': 'zaine.ZaineWatch',
            'SDKROOT': 'watchos',
            'WATCHOS_DEPLOYMENT_TARGET': '9.0',
            'TARGETED_DEVICE_FAMILY': '4',
            'SWIFT_EMIT_LOC_STRINGS': 'YES',
            'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
            'INFOPLIST_KEY_CFBundleDisplayName': 'ZaineWatch',
            'INFOPLIST_KEY_UISupportedInterfaceOrientations': '',
            'ENABLE_PREVIEWS': 'YES',
            'SWIFT_VERSION': '5.0',
            'CODE_SIGN_STYLE': 'Automatic',
            'DEVELOPMENT_TEAM': 'KK27TYK93U',
            'CURRENT_PROJECT_VERSION': '1',
            'MARKETING_VERSION': '1.0',
            'GENERATE_INFOPLIST_FILE': 'YES',
            'INFOPLIST_KEY_WKCompanionAppBundleIdentifier': 'com.zaine.app',
            'INFOPLIST_KEY_LSApplicationCategoryType': '',
            'CODE_SIGN_IDENTITY': 'Apple Development',
            'CODE_SIGN_ALLOW_PROVISIONING_UPDATES': 'YES',
            'PROVISIONING_PROFILE_SPECIFIER': '',
        }
    
    # Step 3: Add source files to Watch App target
    print("\nAdding source files...")
    
    watch_dir = '/Users/meixulin/Desktop/zaine-app/zaine_app/ios/ZaineWatch Watch App Watch App'
    
    # Add ContentView.swift
    project.add_file(
        os.path.join(watch_dir, 'ContentView.swift'),
        parent=watch_target,
        target_name='ZaineWatch Watch App'
    )
    
    # Add ZaineWatch_Watch_AppApp.swift (entry point)
    project.add_file(
        os.path.join(watch_dir, 'ZaineWatch_Watch_AppApp.swift'),
        parent=watch_target,
        target_name='ZaineWatch Watch App'
    )
    
    # Add Assets.xcassets
    project.add_file(
        os.path.join(watch_dir, 'Assets.xcassets'),
        parent=watch_target,
        target_name='ZaineWatch Watch App',
        force=True
    )
    
    # Step 4: Add Embed Watch Content phase to Runner
    print("\nAdding Embed Watch Content phase to Runner...")
    
    # Add PBXCopyFilesBuildPhase for embedding Watch App
    embed_phase = project.add_copy_files_build_phase(
        target_name='Runner',
        name='Embed Watch Content',
        dst_path='$(CONTENTS_FOLDER_PATH)/Watch',
        dst_subfolder_spec=16
    )
    
    # Add Watch App product to this phase
    watch_product = project.objects.get_object(watch_target.productReference)
    if watch_product:
        project.add_build_file(
            watch_product.path,
            target_name='Runner',
            copy_files_build_phase=embed_phase
        )
        print(f"  Added {watch_product.path} to Embed Watch Content phase")
    
    # Step 5: Save project
    print("\nSaving project...")
    project.save()
    print("✅ Project saved successfully!")
    
    # Verify
    print("\nVerifying...")
    project2 = XcodeProject.load(PBXPROJ_PATH)
    for target in project2.objects.get_targets():
        print(f"  Target: {target.name} ({target.productType})")
    
    print("\n✅ Watch App target added successfully!")
    print("Next steps:")
    print("1. Close Xcode completely (Cmd+Q)")
    print("2. Reopen the project")
    print("3. Build with Cmd+B")

if __name__ == '__main__':
    main()
