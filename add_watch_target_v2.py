#!/usr/bin/env python3
"""
直接向 pbxproj 注入 Watch App target（绕过 Xcode GUI 闪退问题）。
注入内容：
1. PBXFileReference - Watch App 产品 + 源文件
2. PBXBuildFile - 编译文件引用
3. PBXSourcesBuildPhase / PBXResourcesBuildPhase
4. PBXNativeTarget - Watch App target
5. XCBuildConfiguration - Debug/Release/Profile
6. XCConfigurationList
7. Project targets 数组
"""

import json
import sys
import plistlib
import subprocess

PBXPROJ = '/Users/meixulin/Desktop/zaine-app/zaine_app/ios/Runner.xcodeproj/project.pbxproj'

def load_pbx(path):
    """读取 pbxproj（它是带 // !$*UTF8*$! 头的 plist）"""
    with open(path, 'rb') as f:
        content = f.read()
    # 去掉 UTF8 声明头
    if content.startswith(b'// !$*UTF8*$!\n'):
        content = content[len(b'// !$*UTF8*$!\n'):]
    # plistlib 加载
    return plistlib.loads(content)

def save_pbx(path, data):
    with open(path, 'wb') as f:
        # 先写 UTF8 头
        f.write(b'// !$*UTF8*$!\n')
        plistlib.dump(data, f, sort_keys=False, skipkeys=False)

def make_id(prefix=''):
    import uuid
    return prefix + str(uuid.uuid4()).replace('-', '').upper()[:24]

def main():
    print(f"Loading {PBXPROJ}...")
    data = load_pbx(PBXPROJ)
    objects = data['objects']
    
    # 检查是否已存在 Watch App target
    for obj_id, obj in objects.items():
        if isinstance(obj, dict) and obj.get('isa') == 'PBXNativeTarget':
            if 'Watch' in obj.get('name', ''):
                print(f"Watch App target already exists: {obj.get('name')} (id={obj_id})")
                print("Aborting to avoid duplicate.")
                return
    
    print("Adding Watch App target...")
    
    # 1. 添加 PBXFileReference
    # Watch App .app 产品
    watch_app_ref = make_id('1A')
    objects[watch_app_ref] = {
        'isa': 'PBXFileReference',
        'explicitFileType': 'wrapper.application',
        'includeInIndex': 0,
        'path': '"ZaineWatch Watch App.app"',
        'sourceTree': 'BUILT_PRODUCTS_DIR',
    }
    
    # ContentView.swift
    content_view_ref = make_id('1B')
    objects[content_view_ref] = {
        'isa': 'PBXFileReference',
        'lastKnownFileType': 'sourcecode.swift',
        'path': 'ContentView.swift',
        'sourceTree': '"<group>"',
    }
    
    # ZaineWatch_Watch_AppApp.swift
    app_swift_ref = make_id('1C')
    objects[app_swift_ref] = {
        'isa': 'PBXFileReference',
        'lastKnownFileType': 'sourcecode.swift',
        'path': 'ZaineWatch_Watch_AppApp.swift',
        'sourceTree': '"<group>"',
    }
    
    # Assets.xcassets
    assets_ref = make_id('1D')
    objects[assets_ref] = {
        'isa': 'PBXFileReference',
        'lastKnownFileType': 'folder.assetcatalog',
        'path': 'Assets.xcassets',
        'sourceTree': '"<group>"',
    }
    
    # Info.plist
    info_plist_ref = make_id('1E')
    objects[info_plist_ref] = {
        'isa': 'PBXFileReference',
        'lastKnownFileType': 'text.plist.xml',
        'path': 'Info.plist',
        'sourceTree': '"<group>"',
    }
    
    print(f"  Added PBXFileReference: {watch_app_ref}, {content_view_ref}, {app_swift_ref}, {assets_ref}, {info_plist_ref}")
    
    # 2. 添加 PBXBuildFile
    content_view_build = make_id('2A')
    objects[content_view_build] = {
        'isa': 'PBXBuildFile',
        'fileRef': content_view_ref,
    }
    
    app_swift_build = make_id('2B')
    objects[app_swift_build] = {
        'isa': 'PBXBuildFile',
        'fileRef': app_swift_ref,
    }
    
    assets_build = make_id('2C')
    objects[assets_build] = {
        'isa': 'PBXBuildFile',
        'fileRef': assets_ref,
    }
    
    info_plist_build = make_id('2D')
    objects[info_plist_build] = {
        'isa': 'PBXBuildFile',
        'fileRef': info_plist_ref,
    }
    
    print(f"  Added PBXBuildFile: {content_view_build}, {app_swift_build}, {assets_build}, {info_plist_build}")
    
    # 3. 添加 PBXSourcesBuildPhase
    sources_phase = make_id('3A')
    objects[sources_phase] = {
        'isa': 'PBXSourcesBuildPhase',
        'buildActionMask': 2147483647,
        'files': [
            app_swift_build,
            content_view_build,
        ],
        'runOnlyForDeploymentPostprocessing': 0,
    }
    
    # 4. 添加 PBXResourcesBuildPhase
    resources_phase = make_id('3B')
    objects[resources_phase] = {
        'isa': 'PBXResourcesBuildPhase',
        'buildActionMask': 2147483647,
        'files': [
            assets_build,
            info_plist_build,
        ],
        'runOnlyForDeploymentPostprocessing': 0,
    }
    
    # 5. 添加 PBXFrameworksBuildPhase (Watch App 可能需要 WatchKit)
    frameworks_phase = make_id('3C')
    objects[frameworks_phase] = {
        'isa': 'PBXFrameworksBuildPhase',
        'buildActionMask': 2147483647,
        'files': [],
        'runOnlyForDeploymentPostprocessing': 0,
    }
    
    print(f"  Added Build Phases: {sources_phase}, {resources_phase}, {frameworks_phase}")
    
    # 6. 添加 XCBuildConfiguration (Debug, Release, Profile)
    config_debug = make_id('4A')
    config_release = make_id('4B')
    config_profile = make_id('4C')
    
    objects[config_debug] = {
        'isa': 'XCBuildConfiguration',
        'buildSettings': {
            'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
            'CODE_SIGN_ENTITLEMENTS': '',
            'CODE_SIGN_STYLE': 'Automatic',
            'CURRENT_PROJECT_VERSION': '1',
            'DEVELOPMENT_TEAM': 'KK27TYK93U',
            'ENABLE_BITCODE': 'NO',
            'INFOPLIST_FILE': 'Info.plist',
            'INFOPLIST_KEY_CFBundleDisplayName': 'ZaineWatch',
            'LD_RUNPATH_SEARCH_PATHS': [
                '$(inherited)',
                '@executable_path/Frameworks',
            ],
            'MARKETING_VERSION': '1.0',
            'PRODUCT_BUNDLE_IDENTIFIER': 'zaine.ZaineWatch',
            'PRODUCT_NAME': '$(TARGET_NAME)',
            'SDKROOT': 'watchos',
            'SKIP_INSTALL': 'YES',
            'SWIFT_VERSION': '5.0',
            'TARGETED_DEVICE_FAMILY': '4',
            'WATCHOS_DEPLOYMENT_TARGET': '9.0',
        },
        'name': 'Debug',
    }
    
    objects[config_release] = {
        'isa': 'XCBuildConfiguration',
        'buildSettings': {
            'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
            'CODE_SIGN_ENTITLEMENTS': '',
            'CODE_SIGN_STYLE': 'Automatic',
            'CURRENT_PROJECT_VERSION': '1',
            'DEVELOPMENT_TEAM': 'KK27TYK93U',
            'ENABLE_BITCODE': 'NO',
            'INFOPLIST_FILE': 'Info.plist',
            'INFOPLIST_KEY_CFBundleDisplayName': 'ZaineWatch',
            'LD_RUNPATH_SEARCH_PATHS': [
                '$(inherited)',
                '@executable_path/Frameworks',
            ],
            'MARKETING_VERSION': '1.0',
            'PRODUCT_BUNDLE_IDENTIFIER': 'zaine.ZaineWatch',
            'PRODUCT_NAME': '$(TARGET_NAME)',
            'SDKROOT': 'watchos',
            'SKIP_INSTALL': 'YES',
            'SWIFT_VERSION': '5.0',
            'TARGETED_DEVICE_FAMILY': '4',
            'WATCHOS_DEPLOYMENT_TARGET': '9.0',
        },
        'name': 'Release',
    }
    
    objects[config_profile] = {
        'isa': 'XCBuildConfiguration',
        'buildSettings': {
            'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
            'CODE_SIGN_ENTITLEMENTS': '',
            'CODE_SIGN_STYLE': 'Automatic',
            'CURRENT_PROJECT_VERSION': '1',
            'DEVELOPMENT_TEAM': 'KK27TYK93U',
            'ENABLE_BITCODE': 'NO',
            'INFOPLIST_FILE': 'Info.plist',
            'INFOPLIST_KEY_CFBundleDisplayName': 'ZaineWatch',
            'LD_RUNPATH_SEARCH_PATHS': [
                '$(inherited)',
                '@executable_path/Frameworks',
            ],
            'MARKETING_VERSION': '1.0',
            'PRODUCT_BUNDLE_IDENTIFIER': 'zaine.ZaineWatch',
            'PRODUCT_NAME': '$(TARGET_NAME)',
            'SDKROOT': 'watchos',
            'SKIP_INSTALL': 'YES',
            'SWIFT_VERSION': '5.0',
            'TARGETED_DEVICE_FAMILY': '4',
            'WATCHOS_DEPLOYMENT_TARGET': '9.0',
        },
        'name': 'Profile',
    }
    
    print(f"  Added XCBuildConfiguration: {config_debug}, {config_release}, {config_profile}")
    
    # 7. 添加 XCConfigurationList
    config_list = make_id('5A')
    objects[config_list] = {
        'isa': 'XCConfigurationList',
        'buildConfigurations': [
            config_debug,
            config_release,
            config_profile,
        ],
        'defaultConfigurationIsVisible': 0,
        'defaultConfigurationName': 'Release',
    }
    
    print(f"  Added XCConfigurationList: {config_list}")
    
    # 8. 添加 PBXNativeTarget
    watch_target = make_id('6A')
    objects[watch_target] = {
        'isa': 'PBXNativeTarget',
        'buildConfigurationList': config_list,
        'buildPhases': [
            frameworks_phase,
            sources_phase,
            resources_phase,
        ],
        'buildRules': [],
        'dependencies': [],
        'name': 'ZaineWatch Watch App',
        'productName': 'ZaineWatch Watch App',
        'productReference': watch_app_ref,
        'productType': 'com.apple.product-type.application.watchapp2',
    }
    
    print(f"  Added PBXNativeTarget: {watch_target} (ZaineWatch Watch App)")
    
    # 9. 添加到 Project 的 targets 数组
    root_id = data['rootObject']
    project_obj = objects[root_id]
    if 'targets' not in project_obj:
        project_obj['targets'] = []
    project_obj['targets'].append(watch_target)
    
    print(f"  Added target {watch_target} to Project.targets")
    
    # 10. 添加 Watch App 文件组到 mainGroup
    main_group_id = project_obj.get('mainGroup')
    if main_group_id and main_group_id in objects:
        main_group = objects[main_group_id]
        # 创建 Watch App 组
        watch_group = make_id('7A')
        objects[watch_group] = {
            'isa': 'PBXGroup',
            'children': [
                app_swift_ref,
                content_view_ref,
                assets_ref,
                info_plist_ref,
            ],
            'path': '"ZaineWatch Watch App Watch App"',
            'sourceTree': '"<group>"',
        }
        main_group['children'].append(watch_group)
        print(f"  Added Watch App group {watch_group} to mainGroup")
    
    # 11. 添加 Watch App .app 到 Products 组
    for obj_id, obj in objects.items():
        if isinstance(obj, dict) and obj.get('isa') == 'PBXGroup' and obj.get('name') == 'Products':
            obj['children'].append(watch_app_ref)
            print(f"  Added Watch App .app to Products group")
            break
    
    # 保存
    print(f"\nSaving to {PBXPROJ}...")
    save_pbx(PBXPROJ, data)
    print("✅ Done! Watch App target added.")
    print(f"\nNext: Open Xcode, it should now see 'ZaineWatch Watch App' target.")
    print("If Xcode crashes on open, the pbxproj may have a syntax error.")
    print("Run: plutil -lint " + PBXPROJ + " to validate.")

if __name__ == '__main__':
    main()
