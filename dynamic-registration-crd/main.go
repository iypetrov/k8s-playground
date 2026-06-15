package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	extensionsv1alpha1 "github.com/gardener/gardener/pkg/apis/extensions/v1alpha1"
	"github.com/go-logr/logr"
	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/apimachinery/pkg/util/uuid"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/cache"
	k8sclient "sigs.k8s.io/controller-runtime/pkg/client"
	metricsserver "sigs.k8s.io/controller-runtime/pkg/metrics/server"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
)

// getRestConfig returns the Kubernetes REST config.
// It first tries in-cluster config, then falls back to KUBECONFIG.
func getRestConfig() (*rest.Config, error) {
	cfg, err := rest.InClusterConfig()
	if err == nil {
		return cfg, nil
	}

	kubeconfig := os.Getenv("KUBECONFIG")
	if kubeconfig == "" {
		return nil, fmt.Errorf("neither in-cluster config nor KUBECONFIG available: %w", err)
	}

	return clientcmd.BuildConfigFromFlags("", kubeconfig)
}

// getLogger returns a configured structured getLogger.
func getLogger() logr.Logger {
	slogLevel := slog.LevelInfo
	opts := &slog.HandlerOptions{
		Level:     slogLevel,
		AddSource: slogLevel == slog.LevelDebug,
	}

	handler := slog.NewTextHandler(os.Stderr, opts)
	return logr.FromSlogHandler(handler)
}

func main() {
	ctx := context.Background()

	scheme := runtime.NewScheme()
	utilruntime.Must(extensionsv1alpha1.AddToScheme(scheme))

	l := getLogger()
	ctrl.SetLogger(l)

	restConfig, err := getRestConfig()
	if err != nil {
		panic("failed to get REST config: " + err.Error())
	}

	mgr, err := ctrl.NewManager(restConfig, ctrl.Options{
		Scheme: scheme,
		Logger: l,
		Cache: cache.Options{
			// Restrict cache to Cluster objects only; this controller does not reconcile other types.
			ByObject: map[k8sclient.Object]cache.ByObject{
				&extensionsv1alpha1.Cluster{}: {},
			},
			// Strip managed fields from all cached objects as they are not used by the reconciler.
			DefaultTransform: cache.TransformStripManagedFields(),
		},
		// Disable metrics and health probe servers.
		Metrics:                metricsserver.Options{BindAddress: "0"},
		HealthProbeBindAddress: "",
	})
	if err != nil {
		panic("failed to create manager: " + err.Error())
	}

	client := mgr.GetClient()
	if err = ctrl.NewControllerManagedBy(mgr).
		For(&extensionsv1alpha1.Cluster{}).
		Named(fmt.Sprintf("cluster-%s", uuid.NewUUID())).
		Complete(reconcile.Func(func(ctx context.Context, r reconcile.Request) (reconcile.Result, error) {
			l.Info("Reconciliation of the extensions.gardener.cloud/v1alpha1 Cluster")
			clusters := &extensionsv1alpha1.ClusterList{}
			if err := client.List(ctx, clusters); err != nil {
				return ctrl.Result{}, fmt.Errorf("failed to list clusters: %w", err)
			}

			l.Info("listed clusters", "count", len(clusters.Items))

			return reconcile.Result{}, nil
		})); err != nil {
		panic("failed to create controller: " + err.Error())
	}

	// Start the manager in a goroutine
	if err := mgr.Start(ctx); err != nil {
		panic("controller-runtime manager stopped with error")
	}
}
