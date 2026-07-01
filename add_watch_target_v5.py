#!/usr/bin/env python3
"""
直接文本方式修改 pbxproj，在每个 section 注入 Watch App 对象。
这是最可靠的方式，完全控制输出格式。
"""

import sys
import re

PBXPROJ = '/Users/meixulin/Desktop/zaine-app/zaine_app/ios/Runner.xcodeproj/project.pbxproj'

def make_id(prefix=''):
    import uuid
    return prefix + str(uuid.uuid4()).replace('-', '').upper()[:24]

def obj_to_openstep(obj, indent=2):
    """将 Python dict 转为 OpenStep 格式"""
    if isinstance(obj, str):
        return obj  # 已经是 OpenStep 字符串
    if isinstance(obj, (list, tuple)):
        items = [obj_to_openstep(x, indent) for x in obj]
        return '(\n' + ',\n'.join(' ' * indent + x for x in items) + ',\n' + ' ' * (indent - 2) + ')'
    if isinstance(obj, dict):
        lines = []
        for k, v in obj.items():
            lines.append(' ' * indent + f'{k} = {obj_to_openstep(v, indent + 2)};')
        return '{\n' + '\n'.join(lines) + '\n' + ' ' * (indent - 2) + '}'
    return repr(obj)

def make_pbx_entry(obj_id, obj):
    """生成 PBX 对象条目"""
    return f'\t\t{obj_id} = {obj_to_openstep(obj, 3)}'

def main():
    print(f"Reading {PBXPROJ}...")
    with open(PBXPROJ, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查是否已存在 Watch App target
    if 'ZaineWatch Watch App' in content and 'PBXNativeTarget' in content:
        # 粗略检查
        if '"ZaineWatch Watch App"' in content or "'ZaineWatch Watch App'" in content:
            print("Watch App target may already exist. Aborting.")
            return
    
    print("Adding Watch App target via text injection...")
    
    # 生成所有 UUID
    ids = {
        'watch_app_ref': make_id('1A'),
        'content_view_ref': make_id('1B'),
        'app_swift_ref': make_id('1C'),
        'assets_ref': make_id('1D'),
        'info_plist_ref': make_id('1E'),
        'content_view_build': make_id('2A'),
        'app_swift_build': make_id('2B'),
        'assets_build': make_id('2C'),
        'info_plist_build': make_id('2D'),
        'sources_phase': make_id('3A'),
        'resources_phase': make_id('3B'),
        'frameworks_phase': make_id('3C'),
        'config_debug': make_id('4A'),
        'config_release': make_id('4B'),
        'config_profile': make_id('4C'),
        'config_list': make_id('5A'),
        'watch_target': make_id('6A'),
        'watch_group': make_id('7A'),
        'embed_phase': make_id('8A'),
        'watch_embed_build': make_id('8B'),
    }
    
    print(f"  IDs generated, watch_target={ids['watch_target']}")
    
    # === 1. 注入 PBXFileReference section ===
    pbx_file_ref_entries = [
        make_pbx_entry(ids['watch_app_ref'], {
            'isa': 'PBXFileReference',
            'explicitFileType': 'wrapper.application',
            'includeInIndex': 0,
            'path': '"ZaineWatch Watch App.app"',
            'sourceTree': 'BUILT_PRODUCTS_DIR',
        }),
        make_pbx_entry(ids['content_view_ref'], {
            'isa': 'PBXFileReference',
            'lastKnownFileType': 'sourcecode.swift',
            'path': 'ContentView.swift',
            'sourceTree': '"<group>"',
        }),
        make_pbx_entry(ids['app_swift_ref'], {
            'isa': 'PBXFileReference',
            'lastKnownFileType': 'sourcecode.swift',
            'path': 'ZaineWatch_Watch_AppApp.swift',
            'sourceTree': '"<group>"',
        }),
        make_pbx_entry(ids['assets_ref'], {
            'isa': 'PBXFileReference',
            'lastKnownFileType': 'folder.assetcatalog',
            'path': 'Assets.xcassets',
            'sourceTree': '"<group>"',
        }),
        make_pbx_entry(ids['info_plist_ref'], {
            'isa': 'PBXFileReference',
            'lastKnownFileType': 'text.plist.xml',
            'path': 'Info.plist',
            'sourceTree': '"<group>"',
        }),
    ]
    
    # 注入到 PBXFileReference section 末尾（End 前）
    inject_point = '/* End PBXFileReference section */'
    inject_str = '\n' + '\n'.join(pbx_file_ref_entries) + '\n'
    content = content.replace(inject_point, inject_str + inject_point)
    print("  Injected PBXFileReference entries")
    
    # === 2. 注入 PBXBuildFile section ===
    pbx_build_file_entries = [
        make_pbx_entry(ids['content_view_build'], {
            'isa': 'PBXBuildFile',
            'fileRef': ids['content_view_ref'],
        }),
        make_pbx_entry(ids['app_swift_build'], {
            'isa': 'PBXBuildFile',
            'fileRef': ids['app_swift_ref'],
        }),
        make_pbx_entry(ids['assets_build'], {
            'isa': 'PBXBuildFile',
            'fileRef': ids['assets_ref'],
        }),
        make_pbx_entry(ids['info_plist_build'], {
            'isa': 'PBXBuildFile',
            'fileRef': ids['info_plist_ref'],
        }),
    ]
    
    inject_point = '/* End PBXBuildFile section */'
    inject_str = '\n' + '\n'.join(pbx_build_file_entries) + '\n'
    content = content.replace(inject_point, inject_str + inject_point)
    print("  Injected PBXBuildFile entries")
    
    # === 3. 注入 PBXSourcesBuildPhase section ===
    sources_phase_obj = {
        'isa': 'PBXSourcesBuildPhase',
        'buildActionMask': 2147483647,
        'files': [ids['app_swift_build'], ids['content_view_build']],
        'runOnlyForDeploymentPostprocessing': 0,
    }
    
    inject_point = '/* End PBXSourcesBuildPhase section */'
    inject_str = '\n' + make_pbx_entry(ids['sources_phase'], sources_phase_obj) + '\n'
    content = content.replace(inject_point, inject_str + inject_point)
    print("  Injected PBXSourcesBuildPhase")
    
    # === 4. 注入 PBXResourcesBuildPhase section ===
    resources_phase_obj = {
        'isa': 'PBXResourcesBuildPhase',
        'buildActionMask': 2147483647,
        'files': [ids['assets_build'], ids['info_plist_build']],
        'runOnlyForDeploymentPostprocessing': 0,
    }
    
    inject_point = '/* End PBXResourcesBuildPhase section */'
    inject_str = '\n' + make_pbx_entry(ids['resources_phase'], resources_phase_obj) + '\n'
    content = content.replace(inject_point, inject_str + inject_point)
    print("  Injected PBXResourcesBuildPhase")
    
    # === 5. 注入 PBXFrameworksBuildPhase section ===
    frameworks_phase_obj = {
        'isa': 'PBXFrameworksBuildPhase',
        'buildActionMask': 2147483647,
        'files': [],
        'runOnlyForDeploymentPostprocessing': 0,
    }
    
    inject_point = '/* End PBXFrameworksBuildPhase section */'
    inject_str = '\n' + make_pbx_entry(ids['frameworks_phase'], frameworks_phase_obj) + '\n'
    content = content.replace(inject_point, inject_str + inject_point)
    print("  Injected PBXFrameworksBuildPhase")
    
    # === 6. 注入 XCBuildConfiguration section ===
    base_settings = {
        'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
        'CODE_SIGN_ENTITLEMENTS': '',
        'CODE_SIGN_STYLE': 'Automatic',
        'CURRENT_PROJECT_VERSION': '1',
        'DEVELOPMENT_TEAM': 'KK27TYK93U',
        'ENABLE_BITCODE': 'NO',
        'INFOPLIST_FILE': 'Info.plist',
        'INFOPLIST_KEY_CFBundleDisplayName': 'ZaineWatch',
        'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks'],
        'MARKETING_VERSION': '1.0',
        'PRODUCT_BUNDLE_IDENTIFIER': 'zaine.ZaineWatch',
        'PRODUCT_NAME': '$(TARGET_NAME)',
        'SDKROOT': 'watchos',
        'SKIP_INSTALL': 'YES',
        'SWIFT_VERSION': '5.0',
        'TARGETED_DEVICE_FAMILY': '4',
        'WATCHOS_DEPLOYMENT_TARGET': '9.0',
    }
    
    config_entries = [
        make_pbx_entry(ids['config_debug'], {
            'isa': 'XCBuildConfiguration',
            'buildSettings': dict(base_settings),
            'name': 'Debug',
        }),
        make_pbx_entry(ids['config_release'], {
            'isa': 'XCBuildConfiguration',
            'buildSettings': dict(base_settings),
            'name': 'Release',
        }),
        make_pbx_entry(ids['config_profile'], {
            'isa': 'XCBuildConfiguration',
            'buildSettings': dict(base_settings),
            'name': 'Profile',
        }),
    ]
    
    inject_point = '/* End XCBuildConfiguration section */'
    inject_str = '\n' + '\n'.join(config_entries) + '\n'
    content = content.replace(inject_point, inject_str + inject_point)
    print("  Injected XCBuildConfiguration entries")
    
    # === 7. 注入 XCConfigurationList section ===
    config_list_obj = {
        'isa': 'XCConfigurationList',
        'buildConfigurations': [ids['config_debug'], ids['config_release'], ids['config_profile']],
        'defaultConfigurationIsVisible': 0,
        'defaultConfigurationName': 'Release',
    }
    
    inject_point = '/* End XCConfigurationList section */'
    inject_str = '\n' + make_pbx_entry(ids['config_list'], config_list_obj) + '\n'
    content = content.replace(inject_point, inject_str + inject_point)
    print("  Injected XCConfigurationList")
    
    # === 8. 注入 PBXNativeTarget section ===
    watch_target_obj = {
        'isa': 'PBXNativeTarget',
        'buildConfigurationList': ids['config_list'],
        'buildPhases': [ids['frameworks_phase'], ids['sources_phase'], ids['resources_phase']],
        'buildRules': [],
        'dependencies': [],
        'name': 'ZaineWatch Watch App',
        'productName': 'ZaineWatch Watch App',
        'productReference': ids['watch_app_ref'],
        'productType': 'com.apple.product-type.application.watchapp2',
    }
    
    inject_point = '/* End PBXNativeTarget section */'
    inject_str = '\n' + make_pbx_entry(ids['watch_target'], watch_target_obj) + '\n'
    content = content.replace(inject_point, inject_str + inject_point)
    print("  Injected PBXNativeTarget")
    
    # === 9. 修改 Project object 的 targets 数组 ===
    # 找到 Project object 的 targets = (...) 行
    def replace_targets(m):
        original = m.group(0)
        # 在 targets 数组末尾添加新 target
        new_target = f'\t\t\t\t{ids["watch_target"]} /* ZaineWatch Watch App */,'
        # 在 ); 前插入
        return original.replace(');\n', new_target + '\n\t\t\t);\n')
    
    content = re.sub(
        r'\t\t\ttargets = \(\n(?:.*?\n)*?\t\t\t\);\n',
        replace_targets,
        content,
        count=1
    )
    print("  Added watch target to Project.targets")
    
    # === 10. 修改 Products group 的 children ===
    def replace_products(m):
        original = m.group(0)
        new_ref = f'\t\t\t\t{ids["watch_app_ref"]} /* ZaineWatch Watch App.app */,'
        return original.replace(');\n', new_ref + '\n\t\t\t);\n')
    
    content = re.sub(
        r'(\t\t\t\t97C146EE1CF9000F007C117D /\* Runner\.app \*/,\n\t\t\t\t331C8081294A63A400263BE5 /\* RunnerTests\.xcest \*/,\n\t\t\t\); )',
        replace_products,
        content
    )
    print("  Added watch app to Products group")
    
    # 保存
    print(f"\nSaving to {PBXPROJ}...")
    with open(PBXPROJ, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Done! Watch App target injected.")
    print(f"\nValidate with: plutil -lint {PBXPROJ}")
    print("Then open Xcode and check if 'ZaineWatch Watch App' target appears.")

if __name__ == '__main__':
    main()
