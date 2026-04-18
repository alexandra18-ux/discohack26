using Gtk;
using GLib;

private const string DAEMON_BUS_NAME = "ru.literallycats.daemon";
private const string DAEMON_OBJECT_PATH = "/ru/literallycats/daemon";
private const string DAEMON_INTERFACE_NAME = "ru.literallycats.daemon";
private const string DBUS_PROPERTIES_INTERFACE_NAME = "org.freedesktop.DBus.Properties";
private const string DBUS_SERVICE_NAME = "org.freedesktop.DBus";
private const string DBUS_SERVICE_PATH = "/org/freedesktop/DBus";
private const string DBUS_SERVICE_INTERFACE = "org.freedesktop.DBus";

private errordomain AuthClientError {
    DAEMON_UNAVAILABLE,
    INVALID_RESPONSE
}

private enum AuthUiState {
    CHECKING,
    UNAUTHENTICATED,
    STARTING_LOGIN,
    WAITING_FOR_COMPLETION,
    AUTHENTICATED,
    ERROR
}

private class BeginLoginPayload : Object {
    public string authorize_url { get; construct; }
    public string code_challenge { get; construct; }
    public string redirect_uri { get; construct; }

    public BeginLoginPayload (string authorize_url, string code_challenge, string redirect_uri) {
        Object (
            authorize_url: authorize_url,
            code_challenge: code_challenge,
            redirect_uri: redirect_uri
        );
    }

    public static BeginLoginPayload from_method_result (Variant result) throws AuthClientError {
        Variant payload = result;

        if (result.n_children () == 1) {
            Variant nested_payload = result.get_child_value (0);
            if (nested_payload.n_children () == 3) {
                payload = nested_payload;
            }
        }

        if (payload.n_children () != 3) {
            throw new AuthClientError.INVALID_RESPONSE (
                "BeginLogin вернул неожиданный ответ: %s".printf (result.get_type_string ())
            );
        }

        return new BeginLoginPayload (
            payload.get_child_value (0).get_string (),
            payload.get_child_value (1).get_string (),
            payload.get_child_value (2).get_string ()
        );
    }
}

private class DaemonAuthClient : Object {
    private DBusConnection? connection;
    private uint login_completed_subscription_id = 0;

    public signal void login_completed ();

    private async DBusConnection ensure_connection () throws Error {
        if (connection == null) {
            connection = yield Bus.get (BusType.SESSION);
            subscribe_to_login_completed (connection);
        }

        return connection;
    }

    private void subscribe_to_login_completed (DBusConnection session_connection) {
        if (login_completed_subscription_id != 0) {
            return;
        }

        login_completed_subscription_id = session_connection.signal_subscribe (
            DAEMON_BUS_NAME,
            DAEMON_INTERFACE_NAME,
            "LoginCompleted",
            DAEMON_OBJECT_PATH,
            null,
            DBusSignalFlags.NONE,
            (conn, sender_name, object_path, interface_name, signal_name, parameters) => {
                login_completed ();
            }
        );
    }

    private async bool has_daemon_owner () throws Error {
        DBusConnection session_connection = yield ensure_connection ();
        Variant result = yield session_connection.call (
            DBUS_SERVICE_NAME,
            DBUS_SERVICE_PATH,
            DBUS_SERVICE_INTERFACE,
            "NameHasOwner",
            new Variant ("(s)", DAEMON_BUS_NAME),
            null,
            DBusCallFlags.NONE,
            -1,
            null
        );

        return result.get_child_value (0).get_boolean ();
    }

    private async void ensure_daemon_available () throws Error {
        if (!yield has_daemon_owner ()) {
            throw new AuthClientError.DAEMON_UNAVAILABLE (
                "Сервис %s не запущен. Запустите backend и попробуйте снова.".printf (DAEMON_BUS_NAME)
            );
        }
    }

    public async void initialize () throws Error {
        yield ensure_connection ();
    }

    public async bool read_is_auth () throws Error {
        DBusConnection session_connection = yield ensure_connection ();
        yield ensure_daemon_available ();

        Variant result = yield session_connection.call (
            DAEMON_BUS_NAME,
            DAEMON_OBJECT_PATH,
            DBUS_PROPERTIES_INTERFACE_NAME,
            "Get",
            new Variant ("(ss)", DAEMON_INTERFACE_NAME, "IsAuth"),
            null,
            DBusCallFlags.NONE,
            -1,
            null
        );

        Variant boxed_value = result.get_child_value (0);
        return boxed_value.get_variant ().get_boolean ();
    }

    public async BeginLoginPayload begin_login () throws Error {
        DBusConnection session_connection = yield ensure_connection ();
        yield ensure_daemon_available ();

        Variant result = yield session_connection.call (
            DAEMON_BUS_NAME,
            DAEMON_OBJECT_PATH,
            DAEMON_INTERFACE_NAME,
            "BeginLogin",
            null,
            null,
            DBusCallFlags.NONE,
            -1,
            null
        );

        return BeginLoginPayload.from_method_result (result);
    }
}

public class MainWindow : ApplicationWindow {
    private Button login_button;
    private Button exit_button;
    private LinkButton manual_link_button;
    private Label status_label;

    private DaemonAuthClient auth_client;
    private AuthUiState current_state = AuthUiState.CHECKING;
    private string? pending_authorize_url = null;

    public MainWindow (Gtk.Application app) {
        Object (
            application: app,
            title: "Авторизация через Яндекс",
            default_width: 460,
            default_height: 260,
            resizable: false
        );

        auth_client = new DaemonAuthClient ();
        auth_client.login_completed.connect (() => {
            on_login_completed ();
        });

        var main_box = new Box (Orientation.VERTICAL, 16);
        main_box.margin_top = 24;
        main_box.margin_bottom = 24;
        main_box.margin_start = 24;
        main_box.margin_end = 24;

        var title_label = new Label ("Вход через Яндекс ID");
        title_label.halign = Align.START;
        title_label.add_css_class ("title-2");
        main_box.append (title_label);

        var subtitle_label = new Label (
            "Приложение получает ссылку авторизации от backend по D-Bus и открывает ее в браузере."
        );
        subtitle_label.halign = Align.START;
        subtitle_label.wrap = true;
        subtitle_label.xalign = 0.0f;
        main_box.append (subtitle_label);

        login_button = new Button.with_label ("Войти через Яндекс");
        login_button.clicked.connect (() => {
            if (current_state == AuthUiState.STARTING_LOGIN || current_state == AuthUiState.WAITING_FOR_COMPLETION) {
                return;
            }

            begin_login_flow.begin ();
        });
        main_box.append (login_button);

        manual_link_button = new LinkButton.with_label ("https://oauth.yandex.ru", "Открыть ссылку авторизации вручную");
        manual_link_button.halign = Align.START;
        manual_link_button.visible = false;
        main_box.append (manual_link_button);

        status_label = new Label ("Статус: проверяем авторизацию…");
        status_label.halign = Align.START;
        status_label.wrap = true;
        status_label.xalign = 0.0f;
        main_box.append (status_label);

        exit_button = new Button.with_label ("Закрыть");
        exit_button.clicked.connect (() => {
            close ();
        });
        main_box.append (exit_button);

        set_child (main_box);

        initialize_auth_client.begin ();
    }

    private async void initialize_auth_client () {
        set_state (AuthUiState.CHECKING, "Статус: подключаемся к session D-Bus…");

        try {
            yield auth_client.initialize ();
        } catch (Error e) {
            set_state (AuthUiState.ERROR, "Ошибка подключения к D-Bus: %s".printf (e.message));
            return;
        }

        refresh_auth_state.begin ();
    }

    private async void refresh_auth_state () {
        if (current_state != AuthUiState.WAITING_FOR_COMPLETION) {
            set_state (AuthUiState.CHECKING, "Статус: проверяем авторизацию…");
        }

        try {
            bool is_auth = yield auth_client.read_is_auth ();
            if (is_auth) {
                pending_authorize_url = null;
                set_state (AuthUiState.AUTHENTICATED, "Статус: авторизация завершена, backend подтвердил вход.");
            } else {
                set_state (AuthUiState.UNAUTHENTICATED, "Статус: вход не выполнен. Нажмите кнопку, чтобы открыть браузер.");
            }
        } catch (Error e) {
            set_state (AuthUiState.ERROR, "Статус: %s".printf (e.message));
        }
    }

    private async void begin_login_flow () {
        set_state (AuthUiState.STARTING_LOGIN, "Статус: запрашиваем ссылку авторизации у backend…");

        try {
            BeginLoginPayload payload = yield auth_client.begin_login ();
            pending_authorize_url = payload.authorize_url;
            manual_link_button.uri = payload.authorize_url;
            manual_link_button.visible = true;

            yield open_authorize_url (payload.authorize_url);
            set_state (AuthUiState.WAITING_FOR_COMPLETION, "Статус: браузер открыт. Завершите вход в Яндексе и дождитесь сигнала LoginCompleted.");
        } catch (Error e) {
            handle_login_error (e);
        }
    }

    private async void open_authorize_url (string authorize_url) throws Error {
        var launcher = new UriLauncher (authorize_url);
        yield launcher.launch (this, null);
    }

    private void handle_login_error (Error error) {
        string message = error.message;

        if (pending_authorize_url != null) {
            manual_link_button.uri = pending_authorize_url;
            manual_link_button.visible = true;
        }

        if ("pending" in message) {
            set_state (AuthUiState.WAITING_FOR_COMPLETION, "Статус: вход уже запущен. Завершите его в браузере или откройте ссылку вручную.");
            return;
        }

        if (pending_authorize_url != null) {
            set_state (AuthUiState.WAITING_FOR_COMPLETION, "Статус: не удалось открыть браузер автоматически (%s). Используйте ссылку ниже.".printf (message));
            return;
        }

        set_state (AuthUiState.UNAUTHENTICATED, "Статус: не удалось начать вход: %s".printf (message));
    }

    private void on_login_completed () {
        set_state (AuthUiState.CHECKING, "Статус: получен сигнал LoginCompleted, проверяем состояние авторизации…");
        refresh_auth_state.begin ();
    }

    private void set_state (AuthUiState new_state, string message) {
        current_state = new_state;
        status_label.label = message;

        bool can_login = new_state != AuthUiState.STARTING_LOGIN
            && new_state != AuthUiState.WAITING_FOR_COMPLETION
            && new_state != AuthUiState.AUTHENTICATED;
        login_button.sensitive = can_login;

        if (new_state == AuthUiState.UNAUTHENTICATED || new_state == AuthUiState.ERROR) {
            if (pending_authorize_url == null) {
                manual_link_button.visible = false;
            }
        }

        if (new_state == AuthUiState.AUTHENTICATED) {
            manual_link_button.visible = false;
        }
    }
}

public class MyApp : Gtk.Application {
    public MyApp () {
        Object (
            application_id: "com.example.yandexauthapp",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
    }

    protected override void activate () {
        var window = new MainWindow (this);
        window.present ();
    }
}

int main (string[] args) {
    var app = new MyApp ();
    return app.run (args);
}
