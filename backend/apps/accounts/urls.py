from django.urls import path

from .views import (
    ChangePasswordView,
    LoginView,
    LogoutView,
    MeView,
    ProfileView,
    RefreshView,
    RegisterView,
    UserDetailView,
    UserListCreateView,
)

urlpatterns = [
    path("login/", LoginView.as_view(), name="login"),
    path("register/", RegisterView.as_view(), name="register"),
    path("refresh/", RefreshView.as_view(), name="refresh"),
    path("logout/", LogoutView.as_view(), name="logout"),
    path("me/", MeView.as_view(), name="me"),
    path("perfil/", ProfileView.as_view(), name="profile"),
    path("cambiar-password/", ChangePasswordView.as_view(), name="change-password"),
    path("users/", UserListCreateView.as_view(), name="users"),
    path("users/<int:pk>/", UserDetailView.as_view(), name="user-detail"),
]