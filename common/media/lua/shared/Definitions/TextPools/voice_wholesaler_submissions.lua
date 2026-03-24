return {
    schemaVersion = 1,
    id = "voice_wholesaler_submissions",
    description = "Wholesaler-voiced submission instructions — volume-focused, distribution-minded",
    entries = {
        { id = "ws_sub_01", text = "Deliver to our distribution point. We will verify quantity and condition. Full payment of ${rewardCash} once the shipment clears intake.", weight = 10 },
        { id = "ws_sub_02", text = "Submit through the terminal network. Our logistics system will route payment automatically on confirmed receipt.", weight = 10 },
        { id = "ws_sub_03", text = "Bring the lot to the warehouse. We handle distribution from there. Your compensation is pre-authorised.", weight = 8 },
        { id = "ws_sub_04", text = "Bulk delivery accepted at the standard receiving dock. Volume bonus applies if you exceed the minimum order.", weight = 8 },
        { id = "ws_sub_05", text = "Standard wholesale terms: deliver in bulk, we sort and distribute, you get paid. ${rewardCash} for this consignment.", weight = 6 },
    },
}
