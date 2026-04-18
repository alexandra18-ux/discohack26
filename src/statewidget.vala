using Gtk;

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
