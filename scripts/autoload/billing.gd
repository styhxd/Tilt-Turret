extends Node

const PRODUCT_ID := "remove_forced_ads"

var _plugin: Object
var _connected := false
var price_text := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_plugin = Engine.get_singleton("GodotGooglePlayBilling")
		_connect_plugin()
		_plugin.startConnection()


func _connect_plugin() -> void:
	if _connected or _plugin == null:
		return
	_connected = true
	if _plugin.has_signal("connected"):
		_plugin.connected.connect(_on_connected)
	if _plugin.has_signal("purchases_updated"):
		_plugin.purchases_updated.connect(_on_purchases)
	if _plugin.has_signal("query_purchases_response"):
		_plugin.query_purchases_response.connect(_on_query)


func _on_connected() -> void:
	_plugin.querySkuDetails([PRODUCT_ID], "inapp")
	if _plugin.has_method("queryPurchases"):
		_plugin.queryPurchases("inapp")


func _on_purchases(purchases: Array) -> void:
	for purchase in purchases:
		var token := ""
		var sku := ""
		if typeof(purchase) == TYPE_DICTIONARY:
			token = str(purchase.get("purchase_token", purchase.get("purchaseToken", "")))
			sku = str(purchase.get("sku", purchase.get("productId", PRODUCT_ID)))
			if sku == PRODUCT_ID or str(purchase.get("product_ids", "")).contains(PRODUCT_ID):
				GameState.ads_removed = true
				GameState.save_game()
				Ads.hide_banner()
		if token != "" and _plugin.has_method("acknowledgePurchase"):
			_plugin.acknowledgePurchase(token)


func _on_query(query_result: Dictionary) -> void:
	if typeof(query_result) != TYPE_DICTIONARY:
		return
	var purchases = query_result.get("purchases", [])
	if typeof(purchases) == TYPE_ARRAY:
		_on_purchases(purchases)


func buy_remove_ads() -> bool:
	if GameState.ads_removed:
		return true
	if _plugin != null and _plugin.has_method("purchase"):
		_plugin.purchase(PRODUCT_ID)
		return true
	if OS.has_feature("editor"):
		GameState.ads_removed = true
		GameState.save_game()
		return true
	return false


func restore() -> void:
	if _plugin != null and _plugin.has_method("queryPurchases"):
		_plugin.queryPurchases("inapp")
