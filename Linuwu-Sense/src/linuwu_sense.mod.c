#include <linux/module.h>
#define INCLUDE_VERMAGIC
#include <linux/build-salt.h>
#include <linux/elfnote-lto.h>
#include <linux/export-internal.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

BUILD_SALT;
BUILD_LTO_INFO;

MODULE_INFO(vermagic, VERMAGIC_STRING);
MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};

#ifdef CONFIG_RETPOLINE
MODULE_INFO(retpoline, "Y");
#endif


static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0xbdfb6dbb, "__fentry__" },
	{ 0x5b8239ca, "__x86_return_thunk" },
	{ 0x65487097, "__x86_indirect_thunk_rax" },
	{ 0x92997ed8, "_printk" },
	{ 0x6068bedf, "wmi_evaluate_method" },
	{ 0xa19b956, "__stack_chk_fail" },
	{ 0x37a0cba, "kfree" },
	{ 0x17f341a0, "i8042_lock_chip" },
	{ 0x4fdee897, "i8042_command" },
	{ 0x1b8b95ad, "i8042_unlock_chip" },
	{ 0xfc4152fc, "ec_read" },
	{ 0x9166fada, "strncpy" },
	{ 0x85df9b6c, "strsep" },
	{ 0x8c8569cb, "kstrtoint" },
	{ 0xcd8ce890, "acpi_format_exception" },
	{ 0x754d539c, "strlen" },
	{ 0x5c3c7387, "kstrtoull" },
	{ 0x3c3ff9fd, "sprintf" },
	{ 0xbcab6ee6, "sscanf" },
	{ 0xc9d4d6d1, "wmi_has_guid" },
	{ 0x83eb21c, "rfkill_unregister" },
	{ 0xdb68bbad, "rfkill_destroy" },
	{ 0x9fa7184a, "cancel_delayed_work_sync" },
	{ 0xfee6deec, "filp_open" },
	{ 0x4e659ada, "kernel_write" },
	{ 0xdbc8803a, "filp_close" },
	{ 0xd92deb6b, "acpi_evaluate_object" },
	{ 0xe268387c, "input_event" },
	{ 0x1eb9516e, "round_jiffies_relative" },
	{ 0x2d3385d3, "system_wq" },
	{ 0xb2fcb56d, "queue_delayed_work_on" },
	{ 0x8a490c90, "rfkill_set_sw_state" },
	{ 0xcdce87c, "rfkill_set_hw_state_reason" },
	{ 0x5e7414f8, "rfkill_alloc" },
	{ 0xff282521, "rfkill_register" },
	{ 0xc708f1fe, "ec_write" },
	{ 0xd4835ef8, "dmi_check_system" },
	{ 0x81e6b37f, "dmi_get_system_info" },
	{ 0x2cf56265, "__dynamic_pr_debug" },
	{ 0x7c983a5d, "dmi_walk" },
	{ 0xaba842fe, "wmi_query_block" },
	{ 0x141271bf, "acpi_dev_found" },
	{ 0x7de7bf50, "__acpi_video_get_backlight_type" },
	{ 0x636f1c12, "input_allocate_device" },
	{ 0xca53bd71, "sparse_keymap_setup" },
	{ 0xe50f4c94, "input_set_capability" },
	{ 0xf18bdd75, "wmi_install_notify_handler" },
	{ 0xddb27a80, "input_register_device" },
	{ 0x76ae31fd, "wmi_remove_notify_handler" },
	{ 0x94a35d2, "input_free_device" },
	{ 0x2ba33f5b, "acpi_dev_get_first_match_dev" },
	{ 0xcd42d7a8, "put_device" },
	{ 0x59edf20, "input_set_abs_params" },
	{ 0x5e3f87b5, "__platform_driver_register" },
	{ 0x7f53c159, "platform_device_alloc" },
	{ 0xf3229315, "platform_device_add" },
	{ 0x25abd4a4, "platform_device_put" },
	{ 0xd4212f2c, "debugfs_create_dir" },
	{ 0xd9fa7eda, "debugfs_create_u32" },
	{ 0x21c6a48e, "platform_driver_unregister" },
	{ 0x8e097286, "input_unregister_device" },
	{ 0x401fb9aa, "sysfs_remove_group" },
	{ 0xbfe36436, "platform_profile_remove" },
	{ 0xc41d1b6f, "backlight_device_unregister" },
	{ 0xdbf7334f, "led_classdev_unregister" },
	{ 0x17b0f8ca, "wmi_get_event_data" },
	{ 0xa2fd1e8f, "sparse_keymap_entry_from_scancode" },
	{ 0x5005b54e, "sparse_keymap_report_event" },
	{ 0x67927a0d, "platform_profile_notify" },
	{ 0x6bb495cc, "kernel_read" },
	{ 0xf266d8fb, "backlight_device_register" },
	{ 0x4dfa8d4b, "mutex_lock" },
	{ 0x3213f038, "mutex_unlock" },
	{ 0xca8dd6ab, "sysfs_create_group" },
	{ 0x8db533b4, "led_classdev_register_ext" },
	{ 0x50641e2a, "devm_hwmon_device_register_with_info" },
	{ 0xc80cfaeb, "_dev_err" },
	{ 0xcac33cd4, "platform_profile_register" },
	{ 0xf9a482f9, "msleep" },
	{ 0x55db6a5c, "debugfs_remove" },
	{ 0xf6464829, "platform_device_unregister" },
	{ 0xffeedf6a, "delayed_work_timer_fn" },
	{ 0x46aefd7, "param_ops_bool" },
	{ 0xbe3c9997, "param_ops_int" },
	{ 0x160c03af, "module_layout" },
};

MODULE_INFO(depends, "wmi,rfkill,video,sparse-keymap,platform_profile");

