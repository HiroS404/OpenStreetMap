WIP

# My own readme for references and current objectives/ issues with the code. Feel free to use or merge in the future - M

Plans for usage for Obsidian for better markdown options.

## Current state: Using the README to help me explain the parts clearly and also note down what to refactor when done. Hoping to finish this readme and or refactor by the end of the week (09/08/25). Made this note on 06/08/25

---

# Pages

All dart files and descriptions.

<ins>[/lib](#lib)</ins>
1) [main.dart](#main)
2) [firebase_options.dart](#firebase_options)

<ins> [lib/services](#services) </ins>
1) [restuarant_service.dart](restaurant_service)

<ins>[lib/pages](#pages)</ins>
1) [home_page.dart](#homepage)
2) [openstreetmap.dart](#openstreetmap)
3) [settings_page.dart](#settings_page)
4) [vendo_profile.dart](#vendo_profile)
5) [vendor_dashboard.dart](vendor_dashboard)
6) [vendor_data_registration.dart](vendor_data_registration)

<ins>[lib/pages/owner_login](#owner_login)</ins>
1) [vendor_create_resto_acc.dart](#vendor_create_resto_acc)
2) [vendor_login.dart](#vendor_login)

<ins>[lib/models](#models)</ins>
1) [restarant_model.dart](restaurant_model)
2) [route_loader.dart](route_loader)

<ins>[lib/widgets](#widgets)</ins>
1) [route_modal_controller.dart](route_modal_controller)
2) [search_modal.dart](search_modal)

---
# lib
## main

main function:
- ```void main() async{}```, this runs the app obviously.
Contains:
```
WidgetsFlutterBinding.ensureInitialized()
```
and
```
FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled:
        true, // This enables local caching (to avoid over use of freeplan firebase huhuhu)
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Optional: unlimited cache
  );
```
>[!NOTE]
>Simply the code is for firebase, makes sure firebase is run and set up before the app runs, as well as runs firestore to cache data locally for offline use to minimize limited API usage.

- There are classes that build the BottonNavBar
>[!IMPORTANT]
>BottomNavBar classes to refactored and made into a different .dart file

## firebase_options
<details>
  <summary>Sensitive Info..? Click to open.</summary>
  - API keys are used here. Don't think its a big deal since this is thesis and not for commercial use.
  
>To create an replicate the system on my account to have more usage.

Explaination of each API:


</details>

---
# services
## restaurant_service
---
# pages
## homepage
## openstreetmap
## settings_page
## vendo_profile
## vendor_dashboard
## vendor_data_registration
---
# owner_login
## vendor_create_resto_acc
## vendor_login
---
# models
## restaurant_model
## route_loader
---
# widgets
## route_modal_controller
## search_modal
---
