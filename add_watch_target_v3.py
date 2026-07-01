#!/usr/bin/env python3
"""
用 pbxproj 库的正确方式注入 Watch App target。
pbxproj 使用 openstep-parser 来解析 pbxproj 格式。
"""

import sys
import os

try:
    from pbxproj import XcodeProject
    from pbxproj.PBXGenericObject import PBXGenericObject
    import openstep_parser
except ImportError as e:
    print(f"ERROR: Missing library: {e}")
    print("Run: pip install pbxproj openstep-parser")
    sys.exit(1)

PBXPROJ_PATH = '/Users/meixulin/Desktop/zaine-app/zaine_app/ios/Runner.xcodeproj/project.pbxproj'

def make_id(prefix=''):
    import uuid
    return prefix + str(uuid.uuid4()).replace('-', '').upper()[:24]

def obj(**kwargs):
    """创建一个 PBXGenericObject（字典子类）"""
    o = PBXGenericObject()
    for k, v in kwargs.items():
        o[k] = v
    return o

def main():
    print(f"Loading project: {PBXPROJ_PATH}")
    project = XcodeProject.load(PBXPROJ_PATH)
    
    objects = project.objects
    
    # 检查是否已存在 Watch App target
    for obj_id, o in objects.items():
        if isinstance(o, dict) and o.get('isa') == 'PBXNativeTarget':
            if 'Watch' in o.get('name', ''):
                print(f"Watch App target already exists: {o.get('name')} (id={obj_id})")
                print("Aborting to avoid duplicate.")
                return
    
    print("Adding Watch App target objects...")
    
    # === 1. PBXFileReference ===
    # Watch App .app 产品
    watch_app_ref = make_id('1A')
    objects[watch_app_ref] = obj(
        isa='PBXFileReference',
        explicitFileType='wrapper.application',
        includeInIndex=0,
        path='"ZaineWatch Watch App.app"',
        sourceTree='BUILT_PRODUCTS_DIR',
    )
    
    # ContentView.swift
    content_view_ref = make_id('1B')
    objects[content_view_ref] = obj(
        isa='PBXFileReference',
        lastKnownFileType='sourcecode.swift',
        path='ContentView.swift',
        sourceTree='"<group>"',
    )
    
    # ZaineWatch_Watch_AppApp.swift
    app_swift_ref = make_id('1C')
    objects[app_swift_ref] = obj(
        isa='PBXFileReference',
        lastKnownFileType='sourcecode.swift',
        path='ZaineWatch_Watch_AppApp.swift',
        sourceTree='"<group>"',
    )
    
    # Assets.xcassets
    assets_ref = make_id('1D')
    objects[assets_ref] = obj(
        isa='PBXFileReference',
        lastKnownFileType='folder.assetcatalog',
        path='Assets.xcassets',
        sourceTree='"<group>"',
    )
    
    # Info.plist
    info_plist_ref = make_id('1E')
    objects[info_plist_ref] = obj(
        isa='PBXFileReference',
        lastKnownFileType='text.plist.xml',
        path='Info.plist',
        sourceTree='"<group>"',
    )
    
    print(f"  Added PBXFileReference: {watch_app_ref}, {content_view_ref}, {app_swift_ref}, {assets_ref}, {info_plist_ref}")
    
    # === 2. PBXBuildFile ===
    content_view_build = make_id('2A')
    objects[content_view_build] = obj(
        isa='PBXBuildFile',
        fileRef=content_view_ref,
    )
    
    app_swift_build = make_id('2B')
    objects[app_swift_build] = obj(
        isa='PBXBuildFile',
        fileRef=app_swift_ref,
    )
    
    assets_build = make_id('2C')
    objects[assets_build] = obj(
        isa='PBXBuildFile',
        fileRef=assets_ref,
    )
    
    info_plist_build = make_id('2D')
    objects[info_plist_build] = obj(
        isa='PBXBuildFile',
        fileRef=info_plist_ref,
    )
    
    print(f"  Added PBXBuildFile: {content_view_build}, {app_swift_build}, {assets_build}, {info_plist_build}")
    
    # === 3. PBXSourcesBuildPhase ===
    sources_phase = make_id('3A')
    objects[sources_phase] = obj(
        isa='PBXSourcesBuildPhase',
        buildActionMask=2147483647,
        files=[
            app_swift_build,
            content_view_build,
        ],
        runOnlyForDeploymentPostprocessing=0,
    )
    
    # === 4. PBXResourcesBuildPhase ===
    resources_phase = make_id('3B')
    objects[resources_phase] = obj(
        isa='PBXResourcesBuildPhase',
        buildActionMask=2147483647,
        files=[
            assets_build,
            info_plist_build,
        ],
        runOnlyForDeploymentPostprocessing=0,
    )
    
    # === 5. PBXFrameworksBuildPhase ===
    frameworks_phase = make_id('3C')
    objects[frameworks_phase] = obj(
        isa='PBXFrameworksBuildPhase',
        buildActionMask=2147483647,
        files=[],
        runOnlyForDeploymentPostprocessing=0,
    )
    
    print(f"  Added Build Phases: {sources_phase}, {resources_phase}, {frameworks_phase}")
    
    # === 6. XCBuildConfiguration (Debug, Release, Profile) ===
    config_debug = make_id('4A')
    objects[config_debug] = obj(
        isa='XCBuildConfiguration',
        buildSettings=obj(
            ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',
            CODE_SIGN_ENTITLEMENTS='',
            CODE_SIGN_STYLE='Automatic',
            CURRENT_PROJECT_VERSION='1',
            DEVELOPMENT_TEAM='KK27TYK93U',
            ENABLE_BITCODE='NO',
            INFOPLIST_FILE='Info.plist',
            INFOPLIST_KEY_WKCompanionAppBundleIdentifier='com.zaine.app',
            INFOPLIST_KEY_WKWatchOnlyApp='NO',
            MARKETING_VERSION='1.0',
            PRODUCT_BUNDLE_IDENTIFIER='zaine.ZaineWatch',
            PRODUCT_NAME='$(TARGET_NAME)',
            SDKROOT='watchos',
            SKIP_INSTALL='YES',
            SWIFT_VERSION='5.0',
            TARGETED_DEVICE_FAMILY='4',
            WATCHOS_DEPLOYMENT_TARGET='9.0',
        ),
        name='Debug',
    )
    
    config_release = make_id('4B')
    objects[config_release] = obj(
        isa='XCBuildConfiguration',
        buildSettings=obj(
            ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',
            CODE_SIGN_ENTITLEMENTS='',
            CODE_SIGN_STYLE='Automatic',
            CURRENT_PROJECT_VERSION='1',
            DEVELOPMENT_TEAM='KK27TYK93U',
            ENABLE_BITCODE='NO',
            INFOPLIST_FILE='Info.plist',
            INFOPLIST_KEY_WKCompanionAppBundleIdentifier='com.zaine.app',
            INFOPLIST_KEY_WKWatchOnlyApp='NO',
            MARKETING_VERSION='1.0',
            PRODUCT_BUNDLE_IDENTIFIER='zaine.ZaineWatch',
            PRODUCT_NAME='$(TARGET_NAME)',
            SDKROOT='watchos',
            SKIP_INSTALL='YES',
            SWIFT_VERSION='5.0',
            TARGETED_DEVICE_FAMILY='4',
            WATCHOS_DEPLOYMENT_TARGET='9.0',
        ),
        name='Release',
    )
    
    config_profile = make_id('4C')
    objects[config_profile] = obj(
        isa='XCBuildConfiguration',
        buildSettings=obj(
            ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',
            CODE_SIGN_ENTITLEMENTS='',
            CODE_SIGN_STYLE='Automatic',
            CURRENT_PROJECT_VERSION='1',
            DEVELOPMENT_TEAM='KK27TYK93U',
            ENABLE_BITCODE='NO',
            INFOPLIST_FILE='Info.plist',
            INFOPLIST_KEY_WKCompanionAppBundleIdentifier='com.zaine.app',
            INFOPLIST_KEY_WKWatchOnlyApp='NO',
            MARKETING_VERSION='1.0',
            PRODUCT_BUNDLE_IDENTIFIER='zaine.ZaineWatch',
            PRODUCT_NAME='$(TARGET_NAME)',
            SDKROOT='watchos',
            SKIP_INSTALL='YES',
            SWIFT_VERSION='5.0',
            TARGETED_DEVICE_FAMILY='4',
            WATCHOS_DEPLOYMENT_TARGET='9.0',
        ),
        name='Profile',
    )
    
    print(f"  Added XCBuildConfiguration: {config_debug}, {config_release}, {config_profile}")
    
    # === 7. XCConfigurationList ===
    config_list = make_id('5A')
    objects[config_list] = obj(
        isa='XCConfigurationList',
        buildConfigurations=[
            config_debug,
            config_release,
            config_profile,
        ],
        defaultConfigurationIsVisible=0,
        defaultConfigurationName='Release',
    )
    
    print(f"  Added XCConfigurationList: {config_list}")
    
    # === 8. PBXNativeTarget ===
    watch_target = make_id('6A')
    objects[watch_target] = obj(
        isa='PBXNativeTarget',
        buildConfigurationList=config_list,
        buildPhases=[
            frameworks_phase,
            sources_phase,
            resources_phase,
        ],
        buildRules=[],
        dependencies=[],
        name='ZaineWatch Watch App',
        productName='ZaineWatch Watch App',
        productReference=watch_app_ref,
        productType='com.apple.product-type.application.watchapp2',
    )
    
    print(f"  Added PBXNativeTarget: {watch_target} (ZaineWatch Watch App)")
    
    # === 9. 添加到 Project 的 targets 数组 ===
    root_id = project.rootObject
    root = objects[root_id]
    if 'targets' not in root:
        root['targets'] = []
    root['targets'].append(watch_target)
    print(f"  Added target {watch_target} to Project.targets")
    
    # === 10. 添加到 Products group ===
    # 找到 Products group
    for obj_id, o in objects.items():
        if isinstance(o, dict) and o.get('isa') == 'PBXGroup' and o.get('name') == 'Products':
            if 'children' not in o:
                o['children'] = []
            o['children'].append(watch_app_ref)
            print(f"  Added Watch App .app to Products group")
            break
    
    # === 11. 添加 Watch App 文件组到 mainGroup ===
    main_group_id = root.get('mainGroup')
    if main_group_id and main_group_id in objects:
        main_group = objects[main_group_id]
        watch_group_id = make_id('7A')
        objects[watch_group_id] = obj(
            isa='PBXGroup',
            children=[
                app_swift_ref,
                content_view_ref,
                assets_ref,
                info_plist_ref,
            ],
            path='"ZaineWatch Watch App Watch App"',
            sourceTree='"<group>"',
        )
        if 'children' not in main_group:
            main_group['children'] = []
        main_group['children'].append(watch_group_id)
        print(f"  Added Watch App group {watch_group_id} to mainGroup")
    
    # === 12. 添加 Embed Watch Content 到 Runner target ===
    # 找到 Runner target
    runner_target_id = None
    for obj_id, o in objects.items():
        if isinstance(o, dict) and o.get('isa') == 'PBXNativeTarget' and o.get('name') == 'Runner':
            runner_target_id = obj_id
            break
    
    if runner_target_id:
        # 创建 PBXCopyFilesBuildPhase
        embed_phase = make_id('8A')
        objects[embed_phase] = obj(
            isa='PBXCopyFilesBuildPhase',
            buildActionMask=2147483647,
            dstPath='"$(CONTENTS_FOLDER_PATH)/Watch"',
            dstSubfolderSpec=16,
            files=[
                # 需要先创建 PBXBuildFile 引用
            ],
            name='"Embed Watch Content"',
            runOnlyForDeploymentPostprocessing=0,
        )
        
        # 创建 Watch App 的 PBXBuildFile（用于 embed phase）
        watch_embed_build = make_id('8B')
        objects[watch_embed_build] = obj(
            isa='PBXBuildFile',
            fileRef=watch_app_ref,
        )
        objects[embed_phase]['files'] = [watch_embed_build]
        
        # 添加到 Runner target 的 buildPhases
        runner_target = objects[runner_target_id]
        if 'buildPhases' not in runner_target:
            runner_target['buildPhases'] = []
        runner_target['buildPhases'].append(embed_phase)
        print(f"  Added Embed Watch Content phase {embed_phase} to Runner target")
    
    # 保存
    print(f"\nSaving project to {PBXPROJ_PATH}...")
    project.save()
    print("✅ Project saved successfully!")
    
    # 验证
    print("\nVerifying...")
    project2 = XcodeProject.load(PBXPROJ_PATH)
    for obj_id, o in project2.objects.items():
        if isinstance(o, dict) and o.get('isa') == 'PBXNativeTarget':
            print(f"  Target: {o.get('name')} ({o.get('productType')})")
    
    print("\n✅ Watch App target added successfully!")
    print("Next steps:")
    print("1. Completely close Xcode (Cmd+Q)")
    print("2. Reopen: open /Users/meixulin/Desktop/zaine-app/zaine_app/ios/Runner.xcworkspace")
    print("3. Select 'ZaineWatch Watch App' target")
    print("4. Press Cmd+B to build")

if __name__ == '__main__':
    main()
