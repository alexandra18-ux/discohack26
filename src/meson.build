gtkdep = dependency('gtk4')
giodep = dependency('gio-2.0')

executable(
  'my-vala-gui',
  [
    'main.vala',
    'statewidget.vala',
  ],
  dependencies: [gtkdep, giodep],
  install: true
)
