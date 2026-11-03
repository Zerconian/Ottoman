#pragma once
#include <QAbstractListModel>
#include <QList>
// One content row (Continue watching / Recently added): media items from a server adapter.
struct MediaItem { QString id, name, subtitle, imageUrl; double progress = 0; };
class ItemModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
public:
    enum Roles { Id = Qt::UserRole + 1, Name, Subtitle, ImageUrl, Progress };
    using QAbstractListModel::QAbstractListModel;
    int rowCount(const QModelIndex & = {}) const override { return m_items.size(); }
    QVariant data(const QModelIndex &idx, int role) const override {
        if (!idx.isValid() || idx.row() >= m_items.size()) return {};
        const MediaItem &m = m_items[idx.row()];
        switch (role) { case Id: return m.id; case Name: return m.name; case Subtitle: return m.subtitle;
                        case ImageUrl: return m.imageUrl; case Progress: return m.progress; }
        return {};
    }
    QHash<int, QByteArray> roleNames() const override {
        return {{Id,"itemId"},{Name,"name"},{Subtitle,"subtitle"},{ImageUrl,"imageUrl"},{Progress,"progress"}};
    }
    void reset(const QList<MediaItem> &items) { beginResetModel(); m_items = items; endResetModel(); emit countChanged(); }
    Q_INVOKABLE QString idAt(int row) const { return row >= 0 && row < m_items.size() ? m_items[row].id : QString(); }
signals:
    void countChanged();
private:
    QList<MediaItem> m_items;
};
