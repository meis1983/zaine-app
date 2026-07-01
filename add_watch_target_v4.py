#!/usr/bin/env python3
"""
直接用 openstep_parser 解析 pbxproj，注入 Watch App target。
openstep_parser 可以正确解析 pbxproj 的 OpenStep 格式。
"""

import sys
import os
import json

try:
    import openstep_parser
except ImportError:
    print("ERROR: openstep_parser not installed")
    print("Run: pip install openstep-parser")
    sys.exit(1)

PBXPROJ = '/Users/meixulin/Desktop/zaine-app/zaine_app/ios/Runner.xcodeproj/project.pbxproj'

def make_id(prefix=''):
    import uuid
    return prefix + str(uuid.uuid4()).replace('-', '').upper()[:24]

def load_pbx(path):
    """用 openstep_parser 加载 pbxproj"""
    with open(path, 'rb') as f:
        content = f.read()
    # 去掉 UTF8 头
    if content.startswith(b'// !$*UTF8*$!\n'):
        content = content[len(b'// !$*UTF8*$!\n'):]
    return openstep_parser.parse(content.decode('utf-8'))

def save_pbx(path, data):
    """保存 pbxproj（保持 OpenStep 格式）"""
    with open(path, 'wb') as f:
        f.write(b'// !$*UTF8*$!\n')
        f.write(openstep_parser.unparse(data).encode('utf-8'))

def get_objects(data):
    return data['objects']

def find_targets(data):
    """找到所有 PBXNativeTarget"""
    objects = get_objects(data)
    targets = {}
    for k, v in objects.items():
        if isinstance(v, dict) and v.get('isa') == 'PBXNativeTarget':
            targets[k] = v
    return targets

def main():
    print(f"Loading: {PBXPROJ}")
    data = load_pbx(PBXPROJ)
    objects = get_objects(data)
    
    # 检查是否已存在 Watch App target
    targets = find_targets(data)
    for tid, t in targets.items():
        if 'Watch' in t.get('name', ''):
            print(f"Watch App target already exists: {t.get('name')} (id={tid})")
            print("Aborting.")
            return
    
    print(f"Current targets: {list(targets.keys())}")
    print("Adding Watch App target...")
    
    # 生成 UUID
    watch_app_ref = make_id('1A')        # PBXFileReference - .app
    content_view_ref = make_id('1B')     # PBXFileReference - ContentView.swift
    app_swift_ref = make_id('1C')       # PBXFileReference - ZaineWatch_Watch_AppApp.swift
    assets_ref = make_id('1D')          # PBXFileReference - Assets.xcassets
    info_plist_ref = make_id('1E')     # PBXFileReference - Info.plist
    
    content_view_build = make_id('2A')   # PBXBuildFile
    app_swift_build = make_id('2B')     # PBXBuildFile
    assets_build = make_id('2C')        # PBXBuildFile
    info_plist_build = make_id('2D')   # PBXBuildFile
    
    sources_phase = make_id('3A')       # PBXSourcesBuildPhase
    resources_phase = make_id('3B')     # PBXResourcesBuildPhase
    frameworks_phase = make_id('3C')   # PBXFrameworksBuildPhase
    
    config_debug = make_id('4A')       # XCBuildConfiguration
    config_release = make_id('4B')    # XCBuildConfiguration
    config_profile = make_id('4C')    # XCBuildConfiguration
    
    config_list = make_id('5A')        # XCConfigurationList
    
    watch_target = make_id('6A')      # PBXNativeTarget
    
    watch_group = make_id('7A')       # PBXGroup (文件组)
    embed_phase = make_id('8A')       # PBXCopyFilesBuildPhase (Embed Watch Content)
    watch_embed_build = make_id('8B') # PBXBuildFile (for embed phase)
    
    print(f"  Generated IDs: watch_target={watch_target}, config_list={config_list}")
    
    # === 1. PBXFileReference ===
    objects[watch_app_ref] = {
        'isa': 'PBXFileReference',
        'explicitFileType': 'wrapper.application',
        'includeInIndex': 0,
        'path': '"ZaineWatch Watch App.app"',
        'sourceTree': 'BUILT_PRODUCTS_DIR',
    }
    objects[content_view_ref] = {
        'isa': 'PBXFileReference',
        'lastKnownFileType': 'sourcecode.swift',
        'path': 'ContentView.swift',
        'sourceTree': '"<group>"',
    }
    objects[app_swift_ref] = {
        'isa': 'PBXFileReference',
        'lastKnownFileType': 'sourcecode.swift',
        'path': 'ZaineWatch_Watch_AppApp.swift',
        'sourceTree': '"<group>"',
    }
    objects[assets_ref] = {
        'isa': 'PBXFileReference',
        'lastKnownFileType': 'folder.assetcatalog',
        'path': 'Assets.xcassets',
        'sourceTree': '"<group>"',
    }
    objects[info_plist_ref] = {
        'isa': 'PBXFileReference',
        'lastKnownFileType': 'text.plist.xml',
        'path': 'Info.plist',
        'sourceTree': '"<group>"',
    }
    print("  Added PBXFileReference objects")
    
    # === 2. PBXBuildFile ===
    objects[content_view_build] = {
        'isa': 'PBXBuildFile',
        'fileRef': content_view_ref,
    }
    objects[app_swift_build] = {
        'isa': 'PBXBuildFile',
        'fileRef': app_swift_ref,
    }
    objects[assets_build] = {
        'isa': 'PBXBuildFile',
        'fileRef': assets_ref,
    }
    objects[info_plist_build] = {
        'isa': 'PBXBuildFile',
        'fileRef': info_plist_ref,
    }
    objects[watch_embed_build] = {
        'isa': 'PBXBuildFile',
        'fileRef': watch_app_ref,
    }
    print("  Added PBXBuildFile objects")
    
    # === 3. Build Phases ===
    objects[sources_phase] = {
        'isa': 'PBXSourcesBuildPhase',
        'buildActionMask': 2147483647,
        'files': [app_swift_build, content_view_build],
        'runOnlyForDeploymentPostprocessing': 0,
    }
    objects[resources_phase] = {
        'isa': 'PBXResourcesBuildPhase',
        'buildActionMask': 2147483647,
        'files': [assets_build, info_plist_build],
        'runOnlyForDeploymentPostprocessing': 0,
    }
    objects[frameworks_phase] = {
        'isa': 'PBXFrameworksBuildPhase',
        'buildActionMask': 2147483647,
        'files': [],
        'runOnlyForDeploymentPostprocessing': 0,
    }
    print("  Added Build Phase objects")
    
    # === 4. XCBuildConfiguration ===
    base_settings = {
        'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
        'CODE_SIGN_STYLE': 'Automatic',
        'CURRENT_PROJECT_VERSION': '1',
        'DEVELOPMENT_TEAM': 'KK27TYK93U',
        'ENABLE_BITCODE': 'NO',
        'INFOPLIST_FILE': 'Info.plist',
        'INFOPLIST_KEY_WKCompanionAppBundleIdentifier': 'com.zaine.app',
        'LD_RUNPATH_SEARCH_PATHS': [
            '$(inherited)',
            '@executable_path/Frameworks',
        ],
        'PRODUCT_BUNDLE_IDENTIFIER': 'zaine.ZaineWatch',
        'PRODUCT_NAME': '$(TARGET_NAME)',
        'SDKROOT': 'watchos',
        'SKIP_INSTALL': 'YES',
        'SWIFT_VERSION': '5.0',
        'TARGETED_DEVICE_FAMILY': '4',
        'WATCHOS_DEPLOYMENT_TARGET': '9.0',
    }
    
    objects[config_debug] = {
        'isa': 'XCBuildConfiguration',
        'buildSettings': dict(base_settings),
        'name': 'Debug',
    }
    objects[config_release] = {
        'isa': 'XCBuildConfiguration',
        'buildSettings': dict(base_settings),
        'name': 'Release',
    }
    objects[config_profile] = {
        'isa': 'XCBuildConfiguration',
        'buildSettings': dict(base_settings),
        'name': 'Profile',
    }
    print("  Added XCBuildConfiguration objects")
    
    # === 5. XCConfigurationList ===
    objects[config_list] = {
        'isa': 'XCConfigurationList',
        'buildConfigurations': [config_debug, config_release, config_profile],
        'defaultConfigurationIsVisible': 0,
        'defaultConfigurationName': 'Release',
    }
    print("  Added XCConfigurationList")
    
    # === 6. PBXNativeTarget (Watch App) ===
    objects[watch_target] = {
        'isa': 'PBXNativeTarget',
        'buildConfigurationList': config_list,
        'buildPhases': [frameworks_phase, sources_phase, resources_phase],
        'buildRules': [],
        'dependencies': [],
        'name': 'ZaineWatch Watch App',
        'productName': 'ZaineWatch Watch App',
        'productReference': watch_app_ref,
        'productType': 'com.apple.product-type.application.watchapp2',
    }
    print(f"  Added PBXNativeTarget: {watch_target}")
    
    # === 7. 添加到 Project 的 targets ===
    root_id = data.get('rootObject')
    root = objects.get(root_id, {})
    targets_list = root.get('targets', [])
    targets_list.append(watch_target)
    root['targets'] = targets_list
    print(f"  Added {watch_target} to Project.targets")
    
    # === 8. 添加到 Products group ===
    for obj_id, obj in objects.items():
        if isinstance(obj, dict) and obj.get('isa') == 'PBXGroup' and obj.get('name') == 'Products':
            children = obj.get('children', [])
            children.append(watch_app_ref)
            obj['children'] = children
            print(f"  Added Watch App .app to Products group")
            break
    
    # === 9. 添加 Watch App 文件组到 mainGroup ===
    main_group_id = root.get('mainGroup')
    if main_group_id and main_group_id in objects:
        main_group = objects[main_group_id]
        children = main_group.get('children', [])
        
        # 创建 Watch App 文件组
        objects[watch_group] = {
            'isa': 'PBXGroup',
            'children': [app_swift_ref, content_view_ref, assets_ref, info_plist_ref],
            'path': '"ZaineWatch Watch App Watch App"',
            'sourceTree': '"<group>"',
        }
        children.append(watch_group)
        main_group['children'] = children
        print(f"  Added Watch App file group to mainGroup")
    
    # === 10. 添加 Embed Watch Content 到 Runner target ===
    for obj_id, obj in objects.items():
        if isinstance(obj, dict) and obj.get('isa') == 'PBXNativeTarget' and obj.get('name') == 'Runner':
            build_phases = obj.get('buildPhases', [])
            
            # 创建 Embed Watch Content phase
            objects[embed_phase] = {
                'isa': 'PBXCopyFilesBuildPhase',
                'buildActionMask': 2147483647,
                'dstPath': '"$(CONTENTS_FOLDER_PATH)/Watch"',
                'dstSubfolderSpec': 16,
                'files': [watch_embed_build],
                'name': '"Embed Watch Content"',
                'runOnlyForDeploymentPostprocessing': 0,
            }
            build_phases.append(embed_phase)
            obj['buildPhases'] = build_phases
            print(f"  Added Embed Watch Content phase to Runner target")
            break
    
    # 保存
    print(f"\nSaving to {PBXPROJ}...")
    save_pbx(PBXPROJ, data)
    print("✅ Project saved successfully!")
    
    # 验证
    print("\nVerifying...")
    data2 = load_pbx(PBXPROJ)
    targets2 = find_targets(data2)
    print(f"  Targets found: {list(targets2.keys())}")
    for tid, t in targets2.items():
        print(f"    - {t.get('name')} ({t.get('productType')})")
    
    print("\n✅ Watch App target added successfully!")
    print("\nNext steps:")
    print("1. Completely close Xcode (Cmd+Q)")
    print("2. Reopen: open /Users/meixulin/Desktop/zaine-app/zaine_app/ios/Runner.xcworkspace")
    print("3. Select 'ZaineWatch Watch App' target")
    print("4. Press Cmd+B to build")

if __name__ == '__main__':
    main()
