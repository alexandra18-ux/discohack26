using Gtk;
using GLib;

public enum StatusState {
    IDLE,
    LOADING,
    ERROR
}

public class StatusStateWidget : Box {
    private Image icon;
    private Spinner spinner;
    private Label title_label;
    private Label message_label;

    public StatusStateWidget() {
        Object(orientation: Orientation.VERTICAL, spacing: 6);

        margin_top = 12;
        margin_bottom = 12;
        margin_start = 12;
        margin_end = 12;
        halign = Align.FILL;
        valign = Align.START;

        icon = new Image.from_icon_name("dialog-information-symbolic");
        icon.halign = Align.START;

        spinner = new Spinner();
        spinner.halign = Align.START;
        spinner.visible = false;

        title_label = new Label("");
        title_label.halign = Align.START;
        title_label.add_css_class("heading");

        message_label = new Label("");
        message_label.halign = Align.START;
        message_label.wrap = true;
        message_label.xalign = 0.0f;

        append(icon);
        append(spinner);
        append(title_label);
        append(message_label);

        set_state(StatusState.IDLE);
    }

    public void set_state(StatusState state) {
        remove_css_class("error");

        // Все визуальные настройки состояния собраны в одном месте.
        // Если позже появятся новые состояния или другие тексты/иконки,
        // удобнее менять их именно здесь.
        switch (state) {
        case StatusState.IDLE:
            icon.icon_name = "dialog-information-symbolic";
            icon.visible = true;
            spinner.stop();
            spinner.visible = false;
            title_label.label = "Ожидание";
            message_label.label = "Сейчас ничего не происходит.";
            break;
        case StatusState.LOADING:
            icon.icon_name = "content-loading-symbolic";
            icon.visible = false;
            spinner.visible = true;
            spinner.start();
            title_label.label = "Загрузка";
            message_label.label = "Выполняется операция, пожалуйста подождите.";
            break;
        case StatusState.ERROR:
            icon.icon_name = "dialog-error-symbolic";
            icon.visible = true;
            spinner.stop();
            spinner.visible = false;
            title_label.label = "Ошибка";
            message_label.label = "Последняя операция завершилась ошибкой.";
            add_css_class("error");
            break;
        }
    }
}

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
        title_label.halign = Align.START;
        main_box.append(title_label);

        status_widget = new StatusStateWidget();
        main_box.append(status_widget);

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
        description_label.halign = Align.START;
        main_box.append(description_label);

        description_view = new TextView();
        description_view.set_vexpand(true);

        var scrolled = new ScrolledWindow();
        scrolled.set_child(description_view);
        scrolled.set_vexpand(true);
        main_box.append(scrolled);

        enable_check = new CheckButton.with_label("Включить опцию");
        enable_check.toggled.connect(() => {
            on_enable_toggled();
        });
        main_box.append(enable_check);

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
        // Изменение полей не считается ошибкой само по себе.
        // Если пользователь начал исправлять форму после ошибки,
        // возвращаем интерфейс в нейтральное состояние.
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
        // Выбор категории больше не вызывает ошибку напрямую.
        // Ошибка должна быть следствием действия пользователя,
        // например попытки сохранить некорректные данные.
        if (!save_in_progress) {
            status_widget.set_state(StatusState.IDLE);
        }
    }

    private bool has_validation_error() {
        // Здесь удобно расширять правила валидации:
        // - минимальная длина имени
        // - обязательное описание
        // - запрещенные категории и т.д.
        return name_entry.text.strip().length == 0;
    }

    private void finish_save_attempt() {
        save_in_progress = false;

        if (has_validation_error()) {
            status_widget.set_state(StatusState.ERROR);
            return;
        }

        // В демо-режиме успешное завершение операции возвращает
        // виджет в спокойное состояние. Здесь можно позже показать
        // отдельное состояние успеха или уведомление.
        status_widget.set_state(StatusState.IDLE);
    }

    private void on_save_clicked() {
        if (save_in_progress) {
            return;
        }

        save_in_progress = true;
        status_widget.set_state(StatusState.LOADING);

        // Имитируем реальную операцию: сначала loading, потом результат.
        // Здесь можно заменить Timeout.add на сетевой запрос, запись в файл
        // или любую другую асинхронную логику.
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
