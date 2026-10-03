# Contexto del Proyecto: Sa i Fort - Gestor de Consumiciones

## Visión General
Aplicación multiplataforma (Android y Web) para la peña de fiestas **Sa i Fort**. Permite llevar el control de inventario de bebidas/productos, contabilizar las consumiciones individuales en tiempo real y gestionar el cobro de deudas entre los socios de la peña.

---

## Tech Stack & Versiones
- **Framework:** Flutter (versión estable más reciente, soporte Android + Web).
- **Backend / Database:** Firebase Realtime Database (Free Tier).
- **Autenticación:** Firebase Authentication (Email/Password o Google Sign-In).
- **Despliegue Web:** GitHub Pages (vía GitHub Actions).
- **Gestión de Estado sugerida:** `flutter_bloc` o `provider` / `riverpod`.

---

## Funcionalidades y Roles

### 1. Autenticación y Seguridad (Whitelist)
- **Administrador Único:** `damarur92@gmail.com`.
- **Acceso Restringido:** Solo pueden acceder los usuarios registrados previamente en la **Whitelist** gestionada por el administrador.
- Los usuarios fuera de la lista de permitidos no pueden registrar consumiciones ni ver datos del club.

### 2. Rol Administrador (`damarur92@gmail.com`)
- **Gestión de Catálogo:** Crear, editar y eliminar productos con sus respectivos precios unitarios.
- **Gestión de Usuarios:** Dar de alta/baja emails en la whitelist.
- **Visión General:** Consultar el balance global de deudas de cada usuario.
- **Gestión Directa:** Sumar/restar consumiciones a cualquier socio y marcar deudas globales o individuales como pagadas.

### 3. Rol Usuario / Socio
- **Consumo Personal:** Marcar consumiciones propias (añadir unidades de un producto consumido).
- **Liquidación:** Marcar su propia deuda como pagada (al realizar la transferencia/bizum/pago en efectivo). Al confirmar el pago, la deuda personal o contador acumulado vuelve a **0**.
- **Vista Transparente:** Consultar su consumo actual, desglose por producto y total a pagar en € en tiempo real.

---

## Modelo de Datos (Firebase Realtime Database)

```json
{
  "config": {
    "admin_email": "damarur92@gmail.com"
  },
  "whitelist": {
    "uid_o_email_hash": {
      "email": "socio@email.com",
      "name": "Nombre Socio",
      "approved": true,
      "createdAt": 1700000000
    }
  },
  "products": {
    "prod_id_1": {
      "name": "Cerveza",
      "price": 1.50,
      "active": true
    },
    "prod_id_2": {
      "name": "Refresco",
      "price": 1.00,
      "active": true
    }
  },
  "users": {
    "user_uid_1": {
      "email": "socio@email.com",
      "displayName": "Nombre Socio",
      "role": "user"
    }
  },
  "tabs": {
    "user_uid_1": {
      "totalAmount": 4.50,
      "items": {
        "prod_id_1": { "quantity": 2, "unitPrice": 1.50 },
        "prod_id_2": { "quantity": 1, "unitPrice": 1.50 }
      },
      "lastUpdated": 1700000000
    }
  },
  "payments_history": {
    "pay_id_1": {
      "userId": "user_uid_1",
      "amountPaid": 4.50,
      "timestamp": 1700000000,
      "markedBy": "user_uid_1"
    }
  }
}