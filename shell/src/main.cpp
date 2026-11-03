#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "AppModel.h"
#include "Sway.h"
#include "Jellyfin.h"
#include "ItemModel.h"
#include "System.h"
#include "ScreenSaverService.h"
#include "ShellControl.h"
int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    const bool saver = app.arguments().contains(QStringLiteral("--saver"));
    // The application name becomes the Wayland app_id sway matches on: ottoman-shell, or ottoman-saver for the screensaver.
    app.setApplicationName(saver ? QStringLiteral("ottoman-saver") : QStringLiteral("ottoman-shell"));
    app.setDesktopFileName(app.applicationName());
    if (saver) {
        QQmlApplicationEngine saverEngine;
        QString mode = QStringLiteral("clock");   // --mode=clock|aurora|stars from saver.sh (Settings > Display)
        for (const QString &arg : app.arguments()) if (arg.startsWith(QStringLiteral("--mode="))) mode = arg.mid(7);
        saverEngine.rootContext()->setContextProperty(QStringLiteral("saverMode"), mode);
        saverEngine.loadFromModule("Ottoman", "Saver");
        return saverEngine.rootObjects().isEmpty() ? 1 : app.exec();
    }
    Sway sway;
    AppModel apps(&sway);
    Jellyfin jellyfin(&sway);
    ScreenSaverService screenSaver(&sway);
    ShellControl control;
    System system;
    qmlRegisterUncreatableType<ItemModel>("Ottoman", 1, 0, "ItemModel", "provided by Jellyfin");
    QObject::connect(&jellyfin, &Jellyfin::needApp, &apps, [&] { apps.launchFlatpak(QStringLiteral("org.jellyfin.JellyfinDesktop")); });
    QObject::connect(&jellyfin, &Jellyfin::played, &sway, [&](const QString &, bool ok) { if (ok) sway.showApp(QStringLiteral("org.jellyfin.JellyfinDesktop")); });
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("sway"), &sway);
    engine.rootContext()->setContextProperty(QStringLiteral("apps"), &apps);
    engine.rootContext()->setContextProperty(QStringLiteral("jellyfin"), &jellyfin);
    engine.rootContext()->setContextProperty(QStringLiteral("system"), &system);
    engine.rootContext()->setContextProperty(QStringLiteral("control"), &control);
    engine.loadFromModule("Ottoman", "Main");
    if (engine.rootObjects().isEmpty()) return 1;
    return app.exec();
}
