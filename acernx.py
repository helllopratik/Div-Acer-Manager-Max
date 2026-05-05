#!/usr/bin/env python3
import os
import glob
import threading
import time
import subprocess
import customtkinter as ctk
from tkinter import filedialog
from PIL import Image
import shutil

# Configure CustomTkinter
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class AcerNX(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("AcerNX - Gaming Control Center")
        self.geometry("1000x700")
        self.resizable(False, False)

        # Base Sysfs paths
        self.wmi_path = self.find_wmi_path()
        self.platform_profile_path = "/sys/firmware/acpi/platform_profile"
        self.kbd_backlight_path = "/sys/class/leds/acer-wmi::kbd_backlight/brightness"
        
        if self.wmi_path:
            self.four_zone_path = os.path.join(os.path.dirname(self.wmi_path), "four_zoned_kb", "four_zone_mode")
        else:
            self.four_zone_path = None

        # State Variables
        self.fan_mode_var = ctk.StringVar(value="Auto")
        self.profile_var = ctk.StringVar(value="balanced")

        self.setup_ui()
        self.update_hardware_state()

        # Start monitoring thread
        self.running = True
        self.monitor_thread = threading.Thread(target=self.monitor_loop, daemon=True)
        self.monitor_thread.start()

    def find_wmi_path(self):
        base = "/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/"
        if os.path.exists(base):
            for folder in os.listdir(base):
                if folder in ["nitro_sense", "predator_sense"]:
                    return os.path.join(base, folder)
        return None

    def read_sysfs(self, path):
        try:
            if path and os.path.exists(path):
                with open(path, "r") as f:
                    return f.read().strip()
        except Exception:
            pass
        return None

    def write_sysfs(self, path, value):
        if not path or not os.path.exists(path):
            return False
        try:
            with open(path, "w") as f:
                f.write(str(value))
            return True
        except PermissionError:
            # Fallback using pkexec if tmpfiles.d hasn't applied yet
            try:
                subprocess.run(["pkexec", "sh", "-c", f"echo '{value}' > '{path}'"], check=True)
                return True
            except Exception as e:
                print(f"Permission denied and pkexec failed for {path}: {e}")
        except Exception as e:
            print(f"Error writing {value} to {path}: {e}")
        return False

    def setup_ui(self):
        # Layout: Left Sidebar for Nav & Status, Right for Content
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        # --- Sidebar ---
        self.sidebar = ctk.CTkFrame(self, width=250, corner_radius=0, fg_color="#1A1A1A")
        self.sidebar.grid(row=0, column=0, sticky="nsew")
        self.sidebar.grid_rowconfigure(6, weight=1)

        self.logo_label = ctk.CTkLabel(self.sidebar, text="ACERNX", font=ctk.CTkFont(size=32, weight="bold", family="Impact"))
        self.logo_label.grid(row=0, column=0, padx=20, pady=(30, 5))
        self.sub_label = ctk.CTkLabel(self.sidebar, text="GAMING DASHBOARD", font=ctk.CTkFont(size=12, weight="bold"), text_color="#00A8FF")
        self.sub_label.grid(row=1, column=0, padx=20, pady=(0, 30))

        # Nav Buttons
        self.nav_home = ctk.CTkButton(self.sidebar, text="Home Dashboard", fg_color="transparent", text_color=("gray10", "gray90"), hover_color=("gray70", "gray30"), anchor="w", command=lambda: self.select_tab("Home"))
        self.nav_home.grid(row=2, column=0, pady=5, padx=20, sticky="ew")

        self.nav_kb = ctk.CTkButton(self.sidebar, text="Keyboard Lighting", fg_color="transparent", text_color=("gray10", "gray90"), hover_color=("gray70", "gray30"), anchor="w", command=lambda: self.select_tab("Keyboard"))
        self.nav_kb.grid(row=3, column=0, pady=5, padx=20, sticky="ew")

        self.nav_settings = ctk.CTkButton(self.sidebar, text="Advanced Settings", fg_color="transparent", text_color=("gray10", "gray90"), hover_color=("gray70", "gray30"), anchor="w", command=lambda: self.select_tab("Settings"))
        self.nav_settings.grid(row=4, column=0, pady=5, padx=20, sticky="ew")

        # Status Monitor in Sidebar
        self.status_frame = ctk.CTkFrame(self.sidebar, fg_color="#242424", corner_radius=10)
        self.status_frame.grid(row=7, column=0, padx=20, pady=20, sticky="ew")
        
        self.hw_status_label = ctk.CTkLabel(self.status_frame, text="Detecting Hardware...", text_color="orange")
        self.hw_status_label.pack(pady=(10, 5))

        self.temp_label = ctk.CTkLabel(self.status_frame, text="CPU: -- °C", font=ctk.CTkFont(size=18, weight="bold"), text_color="#FF4C4C")
        self.temp_label.pack(pady=5)
        
        self.gpu_temp_label = ctk.CTkLabel(self.status_frame, text="GPU: -- °C", font=ctk.CTkFont(size=18, weight="bold"), text_color="#4CFF4C")
        self.gpu_temp_label.pack(pady=(5, 10))

        # --- Main Content Area ---
        self.content_frame = ctk.CTkFrame(self, fg_color="#0F0F0F", corner_radius=15)
        self.content_frame.grid(row=0, column=1, padx=20, pady=20, sticky="nsew")
        self.content_frame.grid_columnconfigure(0, weight=1)
        self.content_frame.grid_rowconfigure(0, weight=1)

        # Tabs Container
        self.frames = {}
        
        self.frames["Home"] = self.create_home_frame()
        self.frames["Keyboard"] = self.create_keyboard_frame()
        self.frames["Settings"] = self.create_settings_frame()

        self.select_tab("Home")

    def select_tab(self, tab_name):
        # Update button colors
        for btn, name in [(self.nav_home, "Home"), (self.nav_kb, "Keyboard"), (self.nav_settings, "Settings")]:
            if name == tab_name:
                btn.configure(fg_color="#0052CC")
            else:
                btn.configure(fg_color="transparent")

        # Show frame
        for name, frame in self.frames.items():
            if name == tab_name:
                frame.grid(row=0, column=0, sticky="nsew", padx=10, pady=10)
            else:
                frame.grid_forget()

    def create_home_frame(self):
        frame = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        frame.grid_columnconfigure((0, 1), weight=1)

        # Scenario Profiles
        prof_frame = ctk.CTkFrame(frame, corner_radius=10, fg_color="#1E1E1E")
        prof_frame.grid(row=0, column=0, columnspan=2, padx=10, pady=10, sticky="ew")
        
        ctk.CTkLabel(prof_frame, text="Thermal Profile Scenario", font=ctk.CTkFont(size=16, weight="bold")).pack(pady=(15, 10))
        profiles = ["quiet", "low-power", "balanced", "balanced-performance", "performance"]
        self.perf_seg = ctk.CTkSegmentedButton(prof_frame, values=profiles, variable=self.profile_var, command=self.apply_profile,
                                               selected_color="#00A8FF", selected_hover_color="#0088CC")
        self.perf_seg.pack(pady=(0, 20), padx=40, fill="x")

        # Fan Control
        fan_frame = ctk.CTkFrame(frame, corner_radius=10, fg_color="#1E1E1E")
        fan_frame.grid(row=1, column=0, columnspan=2, padx=10, pady=10, sticky="nsew")
        
        ctk.CTkLabel(fan_frame, text="Cooling Configuration", font=ctk.CTkFont(size=16, weight="bold")).pack(pady=(15, 10))
        self.fan_seg = ctk.CTkSegmentedButton(fan_frame, values=["Auto", "Max", "Custom"], variable=self.fan_mode_var, command=self.apply_fan_mode,
                                              selected_color="#FF4C4C", selected_hover_color="#CC3333")
        self.fan_seg.pack(pady=(0, 10), padx=40, fill="x")

        self.custom_fan_frame = ctk.CTkFrame(fan_frame, fg_color="transparent")
        
        ctk.CTkLabel(self.custom_fan_frame, text="CPU Fan Speed (%)").grid(row=0, column=0, padx=10, pady=15, sticky="e")
        self.cpu_fan_slider = ctk.CTkSlider(self.custom_fan_frame, from_=0, to=100, number_of_steps=100, button_color="#FF4C4C", progress_color="#CC3333")
        self.cpu_fan_slider.grid(row=0, column=1, padx=20, pady=15, sticky="ew")
        self.cpu_fan_slider.bind("<ButtonRelease-1>", self.apply_custom_fan)
        
        ctk.CTkLabel(self.custom_fan_frame, text="GPU Fan Speed (%)").grid(row=1, column=0, padx=10, pady=15, sticky="e")
        self.gpu_fan_slider = ctk.CTkSlider(self.custom_fan_frame, from_=0, to=100, number_of_steps=100, button_color="#4CFF4C", progress_color="#33CC33")
        self.gpu_fan_slider.grid(row=1, column=1, padx=20, pady=15, sticky="ew")
        self.gpu_fan_slider.bind("<ButtonRelease-1>", self.apply_custom_fan)
        
        self.custom_fan_frame.grid_columnconfigure(1, weight=1)

        return frame

    def create_keyboard_frame(self):
        frame = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        
        ctk.CTkLabel(frame, text="Keyboard Lighting", font=ctk.CTkFont(size=24, weight="bold")).pack(pady=(20, 30))

        # Global Brightness
        bright_frame = ctk.CTkFrame(frame, fg_color="#1E1E1E", corner_radius=10)
        bright_frame.pack(fill="x", padx=20, pady=10)
        ctk.CTkLabel(bright_frame, text="Backlight Brightness", font=ctk.CTkFont(weight="bold")).pack(pady=10)
        
        self.kbd_slider = ctk.CTkSlider(bright_frame, from_=0, to=100, command=self.apply_kbd_brightness, button_color="#00A8FF", progress_color="#0052CC")
        self.kbd_slider.pack(pady=15, fill="x", padx=60)
        self.kbd_slider.set(100)

        # RGB Modes (if supported)
        self.rgb_frame = ctk.CTkFrame(frame, fg_color="#1E1E1E", corner_radius=10)
        self.rgb_frame.pack(fill="both", expand=True, padx=20, pady=10)
        ctk.CTkLabel(self.rgb_frame, text="RGB Effects (4-Zone Support)", font=ctk.CTkFont(weight="bold")).pack(pady=10)

        self.rgb_mode_var = ctk.StringVar(value="Static")
        modes = ["Static", "Breathing", "Neon", "Wave", "Shifting", "Zoom"]
        self.rgb_menu = ctk.CTkOptionMenu(self.rgb_frame, values=modes, variable=self.rgb_mode_var, command=self.apply_rgb_mode)
        self.rgb_menu.pack(pady=10)
        
        ctk.CTkLabel(self.rgb_frame, text="More RGB customization features coming soon.", text_color="gray").pack(pady=20)

        return frame

    def create_settings_frame(self):
        frame = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        ctk.CTkLabel(frame, text="Advanced System Tweaks", font=ctk.CTkFont(size=24, weight="bold")).pack(pady=(20, 30))

        grid = ctk.CTkFrame(frame, fg_color="#1E1E1E", corner_radius=10)
        grid.pack(fill="both", expand=True, padx=20, pady=10)

        self.toggles = {}
        features = {
            "battery_limiter": ("80% Battery Charge Limit", "Preserves battery lifespan when plugged in"),
            "usb_charging": ("Offline USB Charging", "Charge devices via USB when laptop is off"),
            "lcd_override": ("LCD Overdrive (3ms)", "Reduces screen response time for gaming"),
            "boot_animation_sound": ("Boot Animation Sound", "Play sound during Predator/Nitro boot logo"),
            "backlight_timeout": ("Keyboard Backlight Timeout", "Turn off backlight after 30s of inactivity")
        }

        row = 0
        for sysfs_name, (display_name, desc) in features.items():
            f = ctk.CTkFrame(grid, fg_color="transparent")
            f.pack(fill="x", padx=30, pady=15)
            
            info_f = ctk.CTkFrame(f, fg_color="transparent")
            info_f.pack(side="left")
            ctk.CTkLabel(info_f, text=display_name, font=ctk.CTkFont(size=14, weight="bold")).pack(anchor="w")
            ctk.CTkLabel(info_f, text=desc, font=ctk.CTkFont(size=12), text_color="gray").pack(anchor="w")

            var = ctk.StringVar(value="0")
            self.toggles[sysfs_name] = var
            switch = ctk.CTkSwitch(f, text="", variable=var, onvalue="1", offvalue="0", 
                                   command=lambda name=sysfs_name, v=var: self.toggle_feature(name, v.get()),
                                   progress_color="#00A8FF")
            switch.pack(side="right", pady=10)
            row += 1

        # OS Boot Image Customization (Linux Plymouth/GRUB safe alternative to BIOS flashing)
        boot_f = ctk.CTkFrame(grid, fg_color="transparent")
        boot_f.pack(fill="x", padx=30, pady=15)
        boot_info = ctk.CTkFrame(boot_f, fg_color="transparent")
        boot_info.pack(side="left")
        ctk.CTkLabel(boot_info, text="Custom OS Boot Image", font=ctk.CTkFont(size=14, weight="bold")).pack(anchor="w")
        ctk.CTkLabel(boot_info, text="Change the Linux startup splash screen", font=ctk.CTkFont(size=12), text_color="gray").pack(anchor="w")
        
        self.boot_btn = ctk.CTkButton(boot_f, text="Select Image", command=self.set_custom_boot_image, fg_color="#00A8FF", hover_color="#0052CC")
        self.boot_btn.pack(side="right", pady=10)

        return frame

    def set_custom_boot_image(self):
        file_path = filedialog.askopenfilename(
            title="Select Custom Boot Image",
            filetypes=[("Image Files", "*.png *.jpg *.jpeg")]
        )
        if not file_path:
            return
            
        try:
            self.boot_btn.configure(text="Applying...", state="disabled")
            self.update()
            
            # Since raw BIOS NVRAM writing is completely unsupported/dangerous on Linux,
            # we implement the OS-level boot splash (Plymouth) which achieves the exact same visual effect safely.
            theme_dir = "/usr/share/plymouth/themes/acernx"
            subprocess.run(["pkexec", "sh", "-c", f"mkdir -p {theme_dir}"], check=True)
            
            # Convert image to Plymouth compatible format
            img = Image.open(file_path)
            img_path = "/tmp/splash.png"
            img.save(img_path, format="PNG")
            
            subprocess.run(["pkexec", "sh", "-c", f"cp {img_path} {theme_dir}/splash.png"], check=True)
            
            # Create a simple Plymouth theme
            theme_config = f"""[Plymouth Theme]
Name=AcerNX Custom Boot
Description=A theme that features a custom boot logo
ModuleName=script

[script]
ImageDir={theme_dir}
ScriptFile={theme_dir}/acernx.script
"""
            script_content = """Window.SetBackgroundTopColor (0.0, 0.0, 0.0);
Window.SetBackgroundBottomColor (0.0, 0.0, 0.0);
splash_image = Image("splash.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
placed_image = splash_image.Scale(splash_image.GetWidth(), splash_image.GetHeight());
sprite = Sprite(placed_image);
sprite.SetX(screen_width / 2 - placed_image.GetWidth() / 2);
sprite.SetY(screen_height / 2 - placed_image.GetHeight() / 2);
"""
            
            with open("/tmp/acernx.plymouth", "w") as f:
                f.write(theme_config)
            with open("/tmp/acernx.script", "w") as f:
                f.write(script_content)
                
            subprocess.run(["pkexec", "sh", "-c", f"cp /tmp/acernx.plymouth {theme_dir}/acernx.plymouth && cp /tmp/acernx.script {theme_dir}/acernx.script"], check=True)
            
            # Apply Plymouth theme
            subprocess.run(["pkexec", "sh", "-c", f"plymouth-set-default-theme -R acernx"], check=True)
            
            self.boot_btn.configure(text="Success!", fg_color="green")
            
        except Exception as e:
            print(f"Failed to set boot image: {e}")
            self.boot_btn.configure(text="Failed", fg_color="red")
        finally:
            self.after(3000, lambda: self.boot_btn.configure(text="Select Image", fg_color="#00A8FF", state="normal"))

    # --- Hardware Logic ---
    def update_hardware_state(self):
        if not self.wmi_path:
            self.hw_status_label.configure(text="No Hardware Found", text_color="red")
            return
        
        self.hw_status_label.configure(text=f"Ready: {os.path.basename(self.wmi_path).upper()}", text_color="#00A8FF")

        # Read Profile
        prof = self.read_sysfs(self.platform_profile_path)
        if prof:
            self.profile_var.set(prof)

        # Read Fan Speed
        fs = self.read_sysfs(os.path.join(self.wmi_path, "fan_speed"))
        if fs:
            if fs == "0,0":
                self.fan_mode_var.set("Auto")
            elif fs == "100,100":
                self.fan_mode_var.set("Max")
            else:
                self.fan_mode_var.set("Custom")
                try:
                    cpu, gpu = map(int, fs.split(","))
                    self.cpu_fan_slider.set(cpu)
                    self.gpu_fan_slider.set(gpu)
                except:
                    pass
        self.apply_fan_mode(self.fan_mode_var.get(), update_hw=False)

        # Read Toggles
        for name, var in self.toggles.items():
            val = self.read_sysfs(os.path.join(self.wmi_path, name))
            if val in ["0", "1"]:
                var.set(val)

        # Read KBD
        kbd = self.read_sysfs(self.kbd_backlight_path)
        if kbd and kbd.isdigit():
            self.kbd_slider.set(int(kbd))

    def apply_profile(self, choice):
        self.write_sysfs(self.platform_profile_path, choice)

    def apply_fan_mode(self, choice, update_hw=True):
        if choice == "Custom":
            self.custom_fan_frame.pack(fill="x", padx=40, pady=10)
            if update_hw:
                self.apply_custom_fan(None)
        else:
            self.custom_fan_frame.pack_forget()
            if update_hw:
                val = "100,100" if choice == "Max" else "0,0"
                if self.wmi_path:
                    self.write_sysfs(os.path.join(self.wmi_path, "fan_speed"), val)

    def apply_custom_fan(self, _):
        if self.wmi_path and self.fan_mode_var.get() == "Custom":
            cpu = int(self.cpu_fan_slider.get())
            gpu = int(self.gpu_fan_slider.get())
            self.write_sysfs(os.path.join(self.wmi_path, "fan_speed"), f"{cpu},{gpu}")

    def toggle_feature(self, feature_name, value):
        if self.wmi_path:
            self.write_sysfs(os.path.join(self.wmi_path, feature_name), value)

    def apply_kbd_brightness(self, value):
        self.write_sysfs(self.kbd_backlight_path, int(value))
        
    def apply_rgb_mode(self, choice):
        if not self.four_zone_path:
            return
        modes = {"Static": 1, "Breathing": 2, "Neon": 3, "Wave": 4, "Shifting": 5, "Zoom": 6}
        mode_id = modes.get(choice, 1)
        # Format: mode,speed,brightness,direction,red,green,blue
        payload = f"{mode_id},5,100,0,255,0,0"
        self.write_sysfs(self.four_zone_path, payload)

    def get_cpu_temp(self):
        try:
            zones = glob.glob("/sys/class/thermal/thermal_zone*")
            highest = 0
            for zone in zones:
                type_path = os.path.join(zone, "type")
                if os.path.exists(type_path):
                    with open(type_path, "r") as f:
                        content = f.read()
                        if "x86_pkg_temp" in content or "acpitz" in content:
                            with open(os.path.join(zone, "temp"), "r") as tf:
                                t = int(tf.read().strip()) / 1000.0
                                if t > highest:
                                    highest = t
            if highest > 0:
                return f"{highest:.0f}"
        except:
            pass
        return "--"
        
    def get_gpu_temp(self):
        try:
            hwmons = glob.glob("/sys/class/hwmon/hwmon*")
            for hwmon in hwmons:
                name_path = os.path.join(hwmon, "name")
                if os.path.exists(name_path):
                    with open(name_path, "r") as f:
                        name = f.read().strip()
                        if name in ["nouveau", "amdgpu", "nvme"]:
                            temp_path = os.path.join(hwmon, "temp1_input")
                            if os.path.exists(temp_path):
                                with open(temp_path, "r") as tf:
                                    return f"{int(tf.read().strip()) / 1000.0:.0f}"
        except:
            pass
        return "--"

    def monitor_loop(self):
        while self.running:
            cpu_t = self.get_cpu_temp()
            gpu_t = self.get_gpu_temp()
            self.after(0, lambda c=cpu_t, g=gpu_t: self._update_temps(c, g))
            time.sleep(2)
            
    def _update_temps(self, cpu, gpu):
        self.temp_label.configure(text=f"CPU: {cpu} °C")
        self.gpu_temp_label.configure(text=f"GPU: {gpu} °C")

if __name__ == "__main__":
    app = AcerNX()
    app.mainloop()
