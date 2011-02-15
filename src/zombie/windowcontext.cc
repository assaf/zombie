#include <v8.h>
#include <node.h>

using namespace node;
using namespace v8;

class WindowContext: ObjectWrap {
private:
  int m_count;
  Persistent<Context> context;
  Persistent<Object> global;

public:

  static Persistent<FunctionTemplate> s_ct;
  static void Init(Handle<Object> target) {
    HandleScope scope;

    Local<FunctionTemplate> t = FunctionTemplate::New(New);

    s_ct = Persistent<FunctionTemplate>::New(t);
    s_ct->InstanceTemplate()->SetInternalFieldCount(1);
    s_ct->SetClassName(String::NewSymbol("WindowContext"));

    NODE_SET_PROTOTYPE_METHOD(s_ct, "evaluate", Evaluate);
    NODE_SET_PROTOTYPE_METHOD(s_ct, "global", GetGlobal);

    target->Set(String::NewSymbol("WindowContext"), s_ct->GetFunction());
  }

  WindowContext() : m_count(0) {
    Handle<ObjectTemplate> tmpl = ObjectTemplate::New();
    global = Persistent<Object>::New(Object::New());
    tmpl->SetNamedPropertyHandler(GetGlobalProperty, SetGlobalProperty, NULL, NULL, NULL, global);
    context = Context::New(NULL, tmpl);
  }

  ~WindowContext() {
    context.Dispose();
  }

  static Handle<Value> New(const Arguments& args) {
    HandleScope scope;
    WindowContext* hw = new WindowContext();
    hw->Wrap(args.This());
    return args.This();
  }

  // Evaluate expression (String) or function in this context.
  static Handle<Value> Evaluate(const Arguments& args) {
    HandleScope scope;
    WindowContext* wc = ObjectWrap::Unwrap<WindowContext>(args.This());
    wc->context->Enter();
    Handle<Value> result;
    if (args[0]->IsFunction()) {
      // Execute function in the global scope.
      Function *fn = Function::Cast(*args[0]);
      result = fn->Call(wc->global, 0, NULL);
    } else {
      // Coerce argument into a string and execute that as a function.
      Local<String> source = args[0]->ToString();
      Handle<Script> script = Script::Compile(source);
      result = script->Run();
    }
    // TODO: finally
    wc->context->Exit();
    return scope.Close(result);
  }

  static Handle<Value> GetGlobal(const Arguments& args) {
    WindowContext* wc = ObjectWrap::Unwrap<WindowContext>(args.This());
    return wc->global;
  }

  static Handle<Value> GetGlobalProperty(Local<String> property, const AccessorInfo &info) {
    HandleScope scope;
    Handle<Object> object = info.Data()->ToObject();
    Handle<Value> result = object->Get(property);
    return scope.Close(result);
  }

  static Handle<Value> SetGlobalProperty(Local<String> property, Local<Value> value, const AccessorInfo &info) {
    HandleScope scope;
    Handle<Object> object = info.Data()->ToObject();
    object->Set(property, value);
    return scope.Close(value);
  }
};

Persistent<FunctionTemplate> WindowContext::s_ct;

extern "C" {
  static void init(Handle<Object> target) {
    WindowContext::Init(target);
  }
  NODE_MODULE(windowcontext, init);
}
