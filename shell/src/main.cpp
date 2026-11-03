#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "AppModel.h"
#include "Sway.h"
#include "Jellyfin.h"
#include "ItemModel.h"
int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("ottoman-shell"));      // becomes the Wayland app_id sway matches on
    app.setDesktopFileName(QStringLiteral("ottoman-shell"));
    Sway sway;
    AppModel apps(&sway);
    Jellyfin jellyfin;
    qmlRegisterUncreatableType<ItemModel>("Ottoman", 1, 0, "ItemModel", "provided by Jellyfin");
    QObject::connect(&jellyfin, &Jellyfin::needApp, &apps, [&] { apps.launchFlatpak(QStringLiteral("org.jellyfin.JellyfinDesktop")); });
    QObject::connect(&jellyfin, &Jellyfin::played, &sway, [&](const QString &, bool ok) { if (ok) sway.showApp(QStringLiteral("org.jellyfin.JellyfinDesktop")); });
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("sway"), &sway);
    engine.rootContext()->setContextProperty(QStringLiteral("apps"), &apps);
    engine.rootContext()->setContextProperty(QStringLiteral("jellyfin"), &jellyfin);
    engine.loadFromModule("Ottoman", "Main");
    if (engine.rootObjects().isEmpty()) return 1;
    return app.exec();
}
