# Kubernetes: kubectl, k9s, stern, kubectx/kubens.
#
# Доступы к кластерам живут в ~/.kube/config (права 600) и в git НЕ попадают —
# там рабочие OIDC-параметры. Здесь только то, как с ними удобно работать.
#
# Текущий контекст всегда виден в промпте: прод красным, staging зелёным,
# неопознанный кластер жёлтым (см. секцию kubecontext в .p10k.zsh).

command -v kubectl &>/dev/null || return

# ── kubecolor: тот же kubectl, но вывод подсвечен ──────────────
# Алиас, а не переименование: в скриптах и функциях алиасы не
# раскрываются, поэтому автоматика продолжает звать настоящий kubectl.
if command -v kubecolor &>/dev/null; then
  alias kubectl=kubecolor
  # Автодополнение берём от kubectl — своего у kubecolor нет.
  # compinit к этому моменту уже отработал внутри oh-my-zsh.
  compdef kubecolor=kubectl 2>/dev/null
fi

alias k=kubectl

# ── Просмотр ───────────────────────────────────────────────────
alias kgp='kubectl get pods'
alias kgpw='kubectl get pods -o wide'
alias kgd='kubectl get deploy'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kd='kubectl describe'
alias ktop='kubectl top pods'
# События кластера по времени — первое, куда смотреть, когда под не поднялся
alias kev='kubectl get events --sort-by=.lastTimestamp'

# ── Логи одного пода ───────────────────────────────────────────
alias kl='kubectl logs'
alias klf='kubectl logs -f --tail=200'
# Логи предыдущего запуска — когда под уже упал и перезапустился
alias klp='kubectl logs --previous --tail=200'

# ── Внутрь пода и порты ────────────────────────────────────────
alias kex='kubectl exec -it'
alias kpf='kubectl port-forward'

# ── Рестарт ────────────────────────────────────────────────────
# Rolling restart, а не удаление пода: реплики заменяются по очереди,
# сервис не проседает.
alias krr='kubectl rollout restart deployment'
alias krs='kubectl rollout status deployment'
alias krh='kubectl rollout history deployment'

# ── Контекст и namespace ───────────────────────────────────────
if command -v kubectx &>/dev/null; then
  alias kctx=kubectx            # без аргумента — выбор из списка
  alias kns=kubens
fi

# ── stern: логи сразу со всех подов, подходящих под маску ──────
# kubectl logs умеет только один под; stern держит несколько потоков
# разом, красит каждый под своим цветом и переживает пересоздание пода.
#
#   sl my-service           все поды, в имени которых есть my-service
#   sl deploy/my-service    все поды деплоймента
#   sls app=my-service      по label-селектору
#   sl my-service -s 15m    начиная с событий 15-минутной давности
if command -v stern &>/dev/null; then
  alias sl='stern --tail=100 --timestamps'
  alias sls='stern --tail=100 --timestamps --selector'
fi

# ── Выбор пода через fzf ───────────────────────────────────────
# Список подов текущего namespace; превью — describe выбранного.
_k8s_pick_pod() {
  command kubectl get pods --no-headers -o custom-columns=':metadata.name' 2>/dev/null \
    | fzf --height=60% --reverse --prompt='под> ' \
          --preview 'kubectl describe pod {}' --preview-window=right,60%
}

# klog — выбрать под из списка и смотреть его логи
klog() {
  local pod
  pod="$(_k8s_pick_pod)" || return
  [[ -n "$pod" ]] || return
  command kubectl logs -f --tail=200 "$pod" "$@"
}

# kssh — выбрать под и зайти внутрь (bash, если есть, иначе sh)
kssh() {
  local pod
  pod="$(_k8s_pick_pod)" || return
  [[ -n "$pod" ]] || return
  command kubectl exec -it "$pod" -- \
    sh -c 'command -v bash >/dev/null && exec bash || exec sh'
}

# kdel — выбрать под и удалить (deployment поднимет новый)
kdel() {
  local pod
  pod="$(_k8s_pick_pod)" || return
  [[ -n "$pod" ]] || return
  command kubectl delete pod "$pod"
}
