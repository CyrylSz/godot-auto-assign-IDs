@tool
extends EditorPlugin

var item_folders: Array = ["res://item/items/"]
var root_class_name: String = "ItemData"
var root_class_name_field: LineEdit
const CHECK_INTERVAL = 5.0

var refresh_button: Button
var reset_button: Button
var folder_button: Button
var confirmation_dialog: ConfirmationDialog
var main_button: Button
var toolbar_container: HBoxContainer
var buttons_visible: bool = false
var base_control: Control
var file_check_timer: Timer
var existing_files: Array = []
var refresh_options_dialog: Window
var manual_refresh_button: Button
var auto_refresh_checkbox: CheckBox
var check_interval_spinbox: SpinBox
var folder_manager_dialog: Window
var folder_vbox: VBoxContainer
var add_button: Button
var config: ConfigFile = ConfigFile.new()
var config_path: String = "user://auto_assign_ids.cfg"

func _enter_tree():
	print("[AutoAssignIDs] Plugin enabled.")

	var editor_interface = get_editor_interface()
	base_control = editor_interface.get_base_control()

	if config.load(config_path) == OK:
		item_folders = config.get_value("folders", "item_folders", ["res://item/items/"])
		root_class_name = config.get_value("class", "root_class_name", "ItemData")
	else:
		item_folders = ["res://item/items/"]
		root_class_name = "ItemData"
		config.set_value("folders", "item_folders", item_folders)
		config.set_value("class", "root_class_name", root_class_name)
		config.save(config_path)

	var auto_refresh_enabled = config.get_value("refresh", "auto_refresh_enabled", false)
	var check_interval = config.get_value("refresh", "check_interval", 5.0)

	main_button = Button.new()
	main_button.icon = preload("res://addons/auto_assign_ids/icon.png")
	main_button.flat = true
	main_button.pressed.connect(Callable(self, "toggle_buttons"))

	refresh_button = Button.new()
	refresh_button.text = "Refresh Item IDs"
	refresh_button.pressed.connect(Callable(self, "show_refresh_options"))
	refresh_button.modulate.a = 0
	refresh_button.visible = false

	reset_button = Button.new()
	reset_button.text = "Reset All IDs"
	reset_button.pressed.connect(Callable(self, "show_confirmation_dialog"))
	reset_button.modulate.a = 0
	reset_button.visible = false

	folder_button = Button.new()
	folder_button.icon = preload("res://addons/auto_assign_ids/folder.png")
	folder_button.flat = true
	folder_button.pressed.connect(Callable(self, "open_folder_manager"))
	folder_button.modulate.a = 0
	folder_button.visible = false

	confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.dialog_text = "Are you sure you want to reset ALL item IDs?"
	confirmation_dialog.confirmed.connect(Callable(self, "reset_all_ids"))
	base_control.add_child(confirmation_dialog)

	toolbar_container = HBoxContainer.new()
	toolbar_container.add_child(main_button)
	toolbar_container.add_child(refresh_button)
	toolbar_container.add_child(reset_button)
	toolbar_container.add_child(folder_button)

	add_control_to_container(CONTAINER_TOOLBAR, toolbar_container)

	existing_files = get_all_tres_files(item_folders)

	file_check_timer = Timer.new()
	file_check_timer.wait_time = CHECK_INTERVAL
	file_check_timer.one_shot = false
	file_check_timer.timeout.connect(Callable(self, "check_for_new_files"))
	base_control.add_child(file_check_timer)

	refresh_options_dialog = Window.new()
	refresh_options_dialog.title = "Refresh IDs Settings"
	refresh_options_dialog.size = Vector2(300, 200)
	refresh_options_dialog.visible = false
	refresh_options_dialog.connect("close_requested", Callable(self, "hide_refresh_options"))

	var root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	refresh_options_dialog.add_child(root_control)

	var center_container = CenterContainer.new()
	root_control.add_child(center_container)

	var vbox = VBoxContainer.new()
	center_container.add_child(vbox)

	var manual_label = Label.new()
	manual_label.text = "a) Manual Refresh Button:"
	vbox.add_child(manual_label)
	vbox.add_child(HSeparator.new())
	manual_refresh_button = Button.new()
	manual_refresh_button.text = "Manual Refresh"
	manual_refresh_button.pressed.connect(Callable(self, "assign_ids"))
	vbox.add_child(manual_refresh_button)
	vbox.add_child(HSeparator.new())
	var auto_label = Label.new()
	auto_label.text = "b) Automatic Refresh Settings:"
	vbox.add_child(auto_label)
	auto_refresh_checkbox = CheckBox.new()
	auto_refresh_checkbox.text = "Enable Automatic Refresh"
	auto_refresh_checkbox.button_pressed = auto_refresh_enabled
	vbox.add_child(auto_refresh_checkbox)
	var interval_hbox = HBoxContainer.new()
	var interval_label = Label.new()
	interval_label.text = "Check interval (seconds):"
	interval_hbox.add_child(interval_label)
	check_interval_spinbox = SpinBox.new()
	check_interval_spinbox.min_value = 1
	check_interval_spinbox.max_value = 60
	check_interval_spinbox.step = 1
	check_interval_spinbox.value = check_interval
	interval_hbox.add_child(check_interval_spinbox)
	vbox.add_child(interval_hbox)

	auto_refresh_checkbox.connect("toggled", Callable(self, "on_auto_refresh_toggled"))
	check_interval_spinbox.connect("value_changed", Callable(self, "on_check_interval_changed"))
	base_control.add_child(refresh_options_dialog)

	folder_manager_dialog = Window.new()
	folder_manager_dialog.title = "Manage Item Folders"
	folder_manager_dialog.size = Vector2(400, 300)
	folder_manager_dialog.visible = false
	folder_manager_dialog.connect("close_requested", Callable(self, "save_and_hide_folder_manager"))

	var dialog_vbox = VBoxContainer.new()
	folder_manager_dialog.add_child(dialog_vbox)

	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(400, 200)
	dialog_vbox.add_child(scroll_container)

	folder_vbox = VBoxContainer.new()
	scroll_container.add_child(folder_vbox)

	add_button = Button.new()
	add_button.text = "➕"
	add_button.custom_minimum_size = Vector2(390, 0)
	add_button.pressed.connect(Callable(self, "add_folder_line"))
	folder_vbox.add_child(add_button)

	var class_name_hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "root class_name:"
	class_name_hbox.add_child(label)
	root_class_name_field = LineEdit.new()
	root_class_name_field.custom_minimum_size = Vector2(250, 0)
	class_name_hbox.add_child(root_class_name_field)
	dialog_vbox.add_child(class_name_hbox)

	var save_button = Button.new()
	save_button.text = "💾Save"
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.BLUE
	save_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	save_button.add_theme_stylebox_override("normal", style_box)
	save_button.add_theme_stylebox_override("hover", style_box)
	save_button.add_theme_stylebox_override("pressed", style_box)
	save_button.pressed.connect(Callable(self, "save_folder_paths"))
	dialog_vbox.add_child(save_button)

	base_control.add_child(folder_manager_dialog)

	on_auto_refresh_toggled(auto_refresh_enabled)

	assign_ids()

func _exit_tree():
	print("[AutoAssignIDs] Plugin disabled.")
	remove_control_from_container(CONTAINER_TOOLBAR, toolbar_container)
	toolbar_container.queue_free()
	confirmation_dialog.queue_free()
	file_check_timer.queue_free()
	refresh_options_dialog.queue_free()
	folder_manager_dialog.queue_free()

func toggle_buttons():
	var tween = base_control.create_tween()
	if buttons_visible:
		tween.parallel().tween_property(refresh_button, "modulate:a", 0, 0.5)
		tween.parallel().tween_property(reset_button, "modulate:a", 0, 0.5)
		tween.parallel().tween_property(folder_button, "modulate:a", 0, 0.5)
		tween.tween_callback(Callable(self, "_on_hide_finished"))
	else:
		refresh_button.visible = true
		reset_button.visible = true
		folder_button.visible = true
		tween.parallel().tween_property(refresh_button, "modulate:a", 1, 0.5)
		tween.parallel().tween_property(reset_button, "modulate:a", 1, 0.5)
		tween.parallel().tween_property(folder_button, "modulate:a", 1, 0.5)
		buttons_visible = true

func _on_hide_finished():
	refresh_button.visible = false
	reset_button.visible = false
	folder_button.visible = false
	buttons_visible = false

func show_confirmation_dialog():
	confirmation_dialog.popup_centered()

func show_refresh_options():
	refresh_options_dialog.popup()
	call_deferred("center_window")

func center_window():
	refresh_options_dialog.move_to_center()

func hide_refresh_options():
	refresh_options_dialog.hide()

func on_auto_refresh_toggled(toggled: bool):
	if toggled:
		file_check_timer.wait_time = check_interval_spinbox.value
		if not file_check_timer.is_stopped():
			file_check_timer.stop()
		file_check_timer.start()
	else:
		file_check_timer.stop()
	check_interval_spinbox.editable = toggled
	save_refresh_settings()

func on_check_interval_changed(value: float):
	file_check_timer.wait_time = value
	if not file_check_timer.is_stopped():
		file_check_timer.stop()
		file_check_timer.start()
	save_refresh_settings()

func check_for_new_files():
	assign_ids()
	existing_files = get_all_tres_files(item_folders)

func reset_all_ids():
	var file_paths = get_all_tres_files(item_folders)
	for path in file_paths:
		var resource = load(path)
		if resource and is_subclass_of(resource, root_class_name):
			resource.ID = -1
			ResourceSaver.save(resource, path)
	assign_ids()

func assign_ids():
	var file_paths = get_all_tres_files(item_folders)
	var used_ids = {}
	var resources_to_assign = []

	for path in file_paths:
		var resource = load(path)
		if resource and is_subclass_of(resource, root_class_name):
			if resource.ID in used_ids:
				resources_to_assign.append({"path": path, "resource": resource})
				printerr("[AutoAssignIDs] Duplicate ID=", resource.ID, " detected! Issue fixed automatically.")
			elif resource.ID >= 0:
				used_ids[resource.ID] = true
			else:
				resources_to_assign.append({"path": path, "resource": resource})

	for item in resources_to_assign:
		var new_id = 0
		while used_ids.has(new_id):
			new_id += 1
		item.resource.ID = new_id
		used_ids[new_id] = true
		ResourceSaver.save(item.resource, item.path)
		print("[AutoAssignIDs] Assigned unique ID ", new_id, " to ", item.path)

func get_all_tres_files(folders: Array) -> Array:
	var all_files = []
	var sorted_folders = folders.duplicate()
	sorted_folders.sort()
	for folder in sorted_folders:
		all_files.append_array(get_tres_files_recursive(folder))
	return all_files

func get_tres_files_recursive(folder: String) -> Array:
	var files = []
	var dir = DirAccess.open(folder)
	if dir:
		var subdirs = []
		var tres_files = []
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var path = folder + "/" + file_name
				if dir.current_is_dir():
					subdirs.append(file_name)
				elif file_name.ends_with(".tres"):
					tres_files.append(path)
			file_name = dir.get_next()
		dir.list_dir_end()
		
		subdirs.sort()
		for subdir in subdirs:
			var subdir_path = folder + "/" + subdir
			files.append_array(get_tres_files_recursive(subdir_path))
		
		tres_files.sort()
		files.append_array(tres_files)
	else:
		push_error("[AutoAssignIDs] Couldn't open directory: " + folder)
	return files

func open_folder_manager():
	populate_folder_lines()
	root_class_name_field.text = root_class_name
	folder_manager_dialog.popup()
	call_deferred("center_window_folder_manager")

func center_window_folder_manager():
	folder_manager_dialog.move_to_center()

func save_and_hide_folder_manager():
	save_folder_paths()
	folder_manager_dialog.hide()

func populate_folder_lines():
	for child in folder_vbox.get_children():
		if child != add_button:
			child.queue_free()
	
	for folder in item_folders:
		var hbox = HBoxContainer.new()
		var line_edit = LineEdit.new()
		line_edit.text = folder
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var minus_button = Button.new()
		minus_button.text = "➖"
		minus_button.custom_minimum_size = Vector2(40, 0)
		minus_button.pressed.connect(Callable(self, "remove_folder_line").bind(hbox))
		hbox.add_child(line_edit)
		hbox.add_child(minus_button)
		folder_vbox.add_child(hbox)
	
	folder_vbox.move_child(add_button, folder_vbox.get_child_count() - 1)

func add_folder_line():
	var hbox = HBoxContainer.new()
	var line_edit = LineEdit.new()
	line_edit.text = ""
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var minus_button = Button.new()
	minus_button.text = "➖"
	minus_button.custom_minimum_size = Vector2(40, 0)
	minus_button.pressed.connect(Callable(self, "remove_folder_line").bind(hbox))
	hbox.add_child(line_edit)
	hbox.add_child(minus_button)
	folder_vbox.add_child(hbox)
	folder_vbox.move_child(add_button, folder_vbox.get_child_count() - 1)

func remove_folder_line(hbox: HBoxContainer):
	hbox.queue_free()

func save_folder_paths():
	var new_folders = []
	for child in folder_vbox.get_children():
		if child is HBoxContainer:
			var line_edit = child.get_child(0) as LineEdit
			if line_edit and line_edit.text.strip_edges() != "":
				new_folders.append(line_edit.text.strip_edges())
	var new_root_class_name = root_class_name_field.text
	
	# Only save if something changed
	if new_folders != item_folders or new_root_class_name != root_class_name:
		item_folders = new_folders
		root_class_name = new_root_class_name
		config.set_value("folders", "item_folders", item_folders)
		config.set_value("class", "root_class_name", root_class_name)
		config.save(config_path)
	assign_ids()

func is_subclass_of(resource: Resource, c_name: String) -> bool:
	var script = resource.get_script()
	while script:
		if script.get_global_name() == c_name:
			return true
		script = script.get_base_script()
	return false

func save_refresh_settings():
	config.set_value("refresh", "auto_refresh_enabled", auto_refresh_checkbox.button_pressed)
	config.set_value("refresh", "check_interval", check_interval_spinbox.value)
	config.save(config_path)
