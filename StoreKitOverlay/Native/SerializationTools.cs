namespace StoreKitOverlay.Native
{
    internal class SerializationTools
    {
        internal static void FixSerializationForString(ref string originalString)
        {
            if (string.IsNullOrEmpty(originalString))
                originalString = null;
        }

        internal static void FixSerializationForArray<T>(ref T[] originalArray)
        {
            if (originalArray != null && originalArray.Length == 0)
                originalArray = null;
        }
    }
}
