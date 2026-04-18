using Gtk;
using GLib;

public class MainWindow : ApplicationWindow {
    private Entry name_entry;
    private TextView description_view;
    private CheckButton enable_check;
    private ComboBoxText category_combo;
    private Button save_button;
    private Button clear_button;
    private Button exit_button;
    private StatusStateWidget status_widget;
    private bool save_in_progress = false;

    public MainWindow(Gtk.Application app) {
        Object(
            application: app,
            title: "My Vala GUI",
            default_width: 500,
            default_height: 400
        );

        var main_box = new Box(Orientation.VERTICAL, 12);
        main_box.margin_top = 12;
        main_box.margin_bottom = 12;
        main_box.margin_start = 12;
        main_box.margin_end = 12;

        var title_label = new Label("Пример GUI на Vala + GTK4");
        title_label.visible = false;
        title_label.halign = Align.START;
        main_box.append(title_label);

        var name_label = new Label("Имя:");
        name_label.halign = Align.START;
        main_box.append(name_label);

        name_entry = new Entry();
        name_entry.placeholder_text = "Введите имя";
        name_entry.changed.connect(() => {
            on_name_changed();
        });
        main_box.append(name_entry);

        var description_label = new Label("Описание:");
        description_label.visible = false;
        description_label.halign = Align.START;
        main_box.append(description_label);

        description_view = new TextView();
        description_view.set_vexpand(true);

        var scrolled = new ScrolledWindow();
        scrolled.set_child(description_view);
        scrolled.set_vexpand(true);

        enable_check = new CheckButton.with_label("Включить опцию");
        enable_check.toggled.connect(() => {
            on_enable_toggled();
        });

        var category_label = new Label("Категория:");
        category_label.halign = Align.START;
        main_box.append(category_label);

        category_combo = new ComboBoxText();
        category_combo.append_text("Категория 1");
        category_combo.append_text("Категория 2");
        category_combo.append_text("Категория 3");
        category_combo.set_active(0);
        category_combo.changed.connect(() => {
            on_category_changed();
        });
        main_box.append(category_combo);

        status_widget = new StatusStateWidget();
        main_box.append(status_widget);

        var button_box = new Box(Orientation.HORIZONTAL, 6);

        save_button = new Button.with_label("Сохранить");
        save_button.clicked.connect(() => {
            on_save_clicked();
        });
        button_box.append(save_button);

        clear_button = new Button.with_label("Очистить");
        clear_button.clicked.connect(() => {
            on_clear_clicked();
        });
        button_box.append(clear_button);

        exit_button = new Button.with_label("Выход");
        exit_button.clicked.connect(() => {
            on_exit_clicked();
        });
        button_box.append(exit_button);

        main_box.append(button_box);
        set_child(main_box);
    }

    private void on_name_changed() {
        if (!save_in_progress) {
            status_widget.set_state(StatusState.IDLE);
        }
    }

    private void on_enable_toggled() {
        if (!save_in_progress) {
            status_widget.set_state(StatusState.IDLE);
        }
    }

    private void on_category_changed() {
        if (!save_in_progress) {
            status_widget.set_state(StatusState.IDLE);
        }
    }

    private bool has_validation_error() {
        return name_entry.text.strip().length == 0;
    }

    private void finish_save_attempt() {
        save_in_progress = false;

        if (has_validation_error()) {
            status_widget.set_state(StatusState.ERROR);
            return;
        }

        status_widget.set_state(StatusState.IDLE);
    }

    private void on_save_clicked() {
        if (save_in_progress) {
            return;
        }

        save_in_progress = true;
        status_widget.set_state(StatusState.LOADING);

        Timeout.add(1200, () => {
            finish_save_attempt();
            return Source.REMOVE;
        });
    }

    private void on_clear_clicked() {
        name_entry.text = "";

        var buffer = description_view.buffer;
        buffer.text = "";

        enable_check.active = false;
        category_combo.set_active(0);
        save_in_progress = false;
        status_widget.set_state(StatusState.IDLE);
    }

    private void on_exit_clicked() {
        close();
    }
}

public class MyApp : Gtk.Application {
    public MyApp() {
        Object(
            application_id: "com.example.myvalagui",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate() {
        var window = new MainWindow(this);
        window.present();
    }
}

int main(string[] args) {
    var app = new MyApp();
    return app.run(args);
}
