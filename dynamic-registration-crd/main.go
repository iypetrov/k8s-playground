package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"

	extensionsv1alpha1 "github.com/gardener/gardener/pkg/apis/extensions/v1alpha1"
	"github.com/go-logr/logr"
	apiextensionsv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/apimachinery/pkg/util/uuid"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/dynamic/dynamicinformer"
	"k8s.io/client-go/rest"
	clientgocache "k8s.io/client-go/tools/cache"
	"k8s.io/client-go/tools/clientcmd"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/cache"
	k8sclient "sigs.k8s.io/controller-runtime/pkg/client"
	metricsserver "sigs.k8s.io/controller-runtime/pkg/metrics/server"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
)

// Target CRD we're waiting for.
const (
	targetCRDName  = "clusters.extensions.gardener.cloud"
	targetCRDGroup = "extensions.gardener.cloud"
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

// isCRDEstablished returns true if the given CRD object is Established and names accepted.
func isCRDEstablished(u *unstructured.Unstructured) bool {
	crd := &apiextensionsv1.CustomResourceDefinition{}
	if err := runtime.DefaultUnstructuredConverter.FromUnstructured(u.Object, crd); err != nil {
		return false
	}

	if crd.Spec.Group != targetCRDGroup {
		return false
	}

	established := false
	namesAccepted := false
	for _, c := range crd.Status.Conditions {
		switch c.Type {
		case apiextensionsv1.Established:
			established = c.Status == apiextensionsv1.ConditionTrue
		case apiextensionsv1.NamesAccepted:
			namesAccepted = c.Status == apiextensionsv1.ConditionTrue
		}
	}
	return established && namesAccepted
}

// waitForCRD blocks until the target CRD is observed as Established, then returns.
// It runs a dynamic informer on CustomResourceDefinitions and stops it as soon as the CRD is found.
func waitForCRD(ctx context.Context, l logr.Logger, dynamicClient dynamic.Interface) error {
	gvr := schema.GroupVersionResource{
		Group:    "apiextensions.k8s.io",
		Version:  "v1",
		Resource: "customresourcedefinitions",
	}

	factory := dynamicinformer.NewDynamicSharedInformerFactory(dynamicClient, 0)
	informer := factory.ForResource(gvr).Informer()

	// Cancellable context drives the informer's lifecycle; we cancel it once the CRD shows up.
	informerCtx, cancelInformer := context.WithCancel(ctx)
	defer cancelInformer()

	found := make(chan struct{})
	var once bool

	check := func(obj any) {
		u, ok := obj.(*unstructured.Unstructured)
		if !ok {
			return
		}
		if u.GetName() != targetCRDName {
			return
		}
		if !isCRDEstablished(u) {
			return
		}
		if once {
			return
		}
		once = true
		l.Info("target CRD is established, stopping informer", "crd", targetCRDName)
		close(found)
	}

	if _, err := informer.AddEventHandler(clientgocache.ResourceEventHandlerFuncs{
		AddFunc:    func(obj any) { check(obj) },
		UpdateFunc: func(_, newObj any) { check(newObj) },
	}); err != nil {
		return fmt.Errorf("failed to add event handler: %w", err)
	}

	factory.Start(informerCtx.Done())
	if !clientgocache.WaitForCacheSync(informerCtx.Done(), informer.HasSynced) {
		return fmt.Errorf("failed to sync CRD informer cache")
	}

	l.Info("waiting for CRD to become available", "crd", targetCRDName)

	select {
	case <-found:
		// stopInformer via defer cancels informerCtx, which shuts the informer down.
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func main() {
	ctx := ctrl.SetupSignalHandler()

	scheme := runtime.NewScheme()
	utilruntime.Must(extensionsv1alpha1.AddToScheme(scheme))

	l := getLogger()
	ctrl.SetLogger(l)

	restConfig, err := getRestConfig()
	if err != nil {
		panic("failed to get REST config: " + err.Error())
	}

	dynamicClient, err := dynamic.NewForConfig(restConfig)
	if err != nil {
		panic(err)
	}

	if err := waitForCRD(ctx, l, dynamicClient); err != nil {
		if errors.Is(err, context.Canceled) {
			l.Info("shutdown requested before CRD became available")
			return
		}
		panic("failed waiting for CRD: " + err.Error())
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

	if err := mgr.Start(ctx); err != nil {
		panic("controller-runtime manager stopped with error")
	}
}
