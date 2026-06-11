Разграничение по оргструктуре реализовано через **12 namespace по продуктовым командам** (домен — в префиксе имени и в метке `domain=`):

| Домен (метка `domain=`) | Namespaces |
|---|---|
| `sales` | `sales-storefront`, `sales-mart`, `sales-estate`, `sales-tour`, `sales-crm`, `sales-auth` |
| `jku` | `jku-tenant`, `jku-crm`, `jku-smarthome` (новый сервис «Умный дом», Task 3) |
| `finance` | `finance-accounting` |
| `data` | `data-analytics` |
| `platform` | `platform-system` |

---

## Проверочная таблица ролей

| Роль | Права роли | Группы пользователей |
| --- | --- | --- |
| **`cluster-privileged`**<br>(ClusterRole + ClusterRoleBinding) | Полное управление ресурсами во всех namespace, **включая просмотр и изменение secrets**. Verbs `get, list, watch, create, update, patch, delete` для: core (pods, services, configmaps, **secrets**, persistentvolumeclaims, serviceaccounts), apps (deployments, statefulsets, daemonsets, replicasets), batch (jobs, cronjobs), networking (ingresses, networkpolicies); `get, list, watch` для nodes, namespaces, persistentvolumes. Без `*`. | **`platform`** — платформенная / DevOps-команда. Привилегированная группа, администрирует кластер. |
| **`cluster-security-auditor`**<br>(ClusterRole + ClusterRoleBinding) | Cluster-wide доступ **только на чтение, включая secrets**, плюс просмотр объектов RBAC (roles, rolebindings, clusterroles, clusterrolebindings). Verbs `get, list, watch`. Без прав на запись. Назначение — аудит безопасности. | **`security`** — ИБ-специалист. Привилегированная группа (видит secrets для аудита), но не может изменять кластер. |
| **`cluster-viewer`**<br>(ClusterRole + ClusterRoleBinding) | Просмотр ресурсов во всех namespace: `get, list, watch` для pods, deployments, statefulsets, replicasets, services, configmaps, ingresses, namespaces, events. **Secrets НЕ входят.** | **`viewers`** — операционные команды (менеджеры), владельцы продуктов, руководство. Группа «только просмотр кластера». |
| **`ns-editor`**<br>(Role в каждом namespace + RoleBinding) | Настройка ресурсов **в пределах своего namespace**: `get, list, watch, create, update, patch, delete` для deployments, statefulsets, replicasets, pods, services, configmaps, ingresses. **Без доступа к secrets и к чужим namespace.** | **`<namespace>-dev`** — разработчики и инженеры эксплуатации продуктовой команды (например, `jku-smarthome-dev`). Группа «настройка кластера» в рамках своей команды. |
| **`ns-viewer`**<br>(Role в каждом namespace + RoleBinding) | Просмотр ресурсов **только в своём namespace**: `get, list, watch` для тех же ресурсов, что у `ns-editor`. Без secrets. | **`<namespace>-watch`** — аналитики и менеджеры конкретного продукта (например, `data-analytics-watch`). |

---

## Соответствие пользователей, групп и ролей (демо)

| Пользователь (CN) | Группа (O=) | Роль | Что демонстрирует |
|---|---|---|---|
| `alice-devops` | `platform` | `cluster-privileged` | привилегированный доступ + управление secrets |
| `ivan-security` | `security` | `cluster-security-auditor` | ИБ: чтение всего (incl. secrets), без записи |
| `bob-manager` | `viewers` | `cluster-viewer` | только просмотр кластера, secrets недоступны |
| `carol-dev` | `jku-smarthome-dev` | `ns-editor` @ `jku-smarthome` | настройка только своего namespace |
| `dana-analyst` | `data-analytics-watch` | `ns-viewer` @ `data-analytics` | просмотр только своего namespace |

> Группы `<namespace>-dev` и `<namespace>-watch` существуют для каждого из 12 namespace; в демонстрации показаны две из них.
