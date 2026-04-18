nautilus_extension_dir = get_option('nautilus_extension_dir')
if nautilus_extension_dir == ''
  nautilus_extension_dir = join_paths(get_option('datadir'), 'nautilus-python', 'extensions')
endif

install_data(
  'syncstatus.py',
  install_dir: nautilus_extension_dir,
)
