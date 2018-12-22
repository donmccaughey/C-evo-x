using System;
using System.Collections.Generic;
using System.Reflection;

namespace Loader
{
	class AIPlugin
	{
		static Dictionary<string, Type> typeCache = new Dictionary<string, Type>();

		Object instance = null;
		MethodInfo initializeMethod = null;
		MethodInfo callMethod = null;

		public AIPlugin(string assemblyPath)
		{
			try
			{
				Type type = null;
				if (!typeCache.TryGetValue(assemblyPath, out type))
				{
					Assembly assembly = Assembly.LoadFile(assemblyPath);
					type = assembly.GetType("AI.Plugin");
					typeCache[assemblyPath] = type;
				}
				initializeMethod = type.GetMethod("Initialize");
				callMethod = type.GetMethod("Call");
				instance = Activator.CreateInstance(type);
			}
			catch (Exception)
			{
				initializeMethod = null;
				callMethod = null;
				instance = null;
			}
		}

		public Object Initialize(params Object[] args)
		{
			if (initializeMethod == null || instance == null)
				return null;
			else
			{
				try
				{
					return initializeMethod.Invoke(instance, args);
				}
				catch (Exception)
				{
					return null;
				}
			}
		}

		public Object Call(params Object[] args)
		{
			if (callMethod == null || instance == null)
				return null;
			else
			{
				try
				{
					return callMethod.Invoke(instance, args);
				}
				catch (Exception)
				{
					return null;
				}
			}
		}
	}
}
